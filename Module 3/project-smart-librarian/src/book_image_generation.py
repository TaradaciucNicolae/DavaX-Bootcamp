# Image prompt construction and OpenAI image generation helpers.

import base64
import re
import unicodedata
from typing import Any

from src.config import (
    IMAGE_COVER_SIZE,
    IMAGE_MODEL,
    IMAGE_OUTPUT_FORMAT,
    IMAGE_QUALITY,
    IMAGE_SCENE_SIZE,
    IMAGE_STYLE,
)
from src.embeddings import get_openai_client

IMAGE_VARIANTS = {"cover", "scene"}
IMAGE_MIME_TYPES = {
    "png": "image/png",
    "jpeg": "image/jpeg",
    "webp": "image/webp",
}
MAX_IMAGE_CONTEXT_CHARS = 700
IMAGE_SAFETY_REPLACEMENTS = (
    (r"\bscandalous\b", "dramatic"),
    (r"\bseductive\b", "charismatic"),
    (r"\bseduction\b", "tension"),
    (r"\bsensual\b", "elegant"),
    (r"\bdesire\b", "longing"),
    (r"\blust\b", "yearning"),
    (r"\berotic\b", "romantic"),
    (r"\bsex(?:ual)?\b", "romance"),
    (r"\bintimate\b", "personal"),
    (r"\bnudity\b", "symbolism"),
)


def _normalize_spaces(text: str) -> str:
    # Collapse repeated whitespace before prompt assembly.
    return re.sub(r"\s+", " ", (text or "")).strip()


def _trim_context_text(text: str, max_chars: int = MAX_IMAGE_CONTEXT_CHARS) -> str:
    # Trim long context while preserving as much sentence structure as possible.
    cleaned_text = _normalize_spaces(text)
    if len(cleaned_text) <= max_chars:
        return cleaned_text

    truncated_text = cleaned_text[:max_chars].rstrip()
    last_break = max(
        truncated_text.rfind(". "),
        truncated_text.rfind("! "),
        truncated_text.rfind("? "),
        truncated_text.rfind("; "),
    )

    if last_break >= int(max_chars * 0.6):
        return truncated_text[: last_break + 1].strip()

    last_space = truncated_text.rfind(" ")
    if last_space > 0:
        return truncated_text[:last_space].strip()

    return truncated_text


def _get_variant_size(variant: str) -> str:
    # Return the configured image size for each supported variant.
    if variant == "cover":
        return IMAGE_COVER_SIZE
    return IMAGE_SCENE_SIZE


def _get_variant_slug(variant: str) -> str:
    # Return the filename slug used for the selected image variant.
    if variant == "cover":
        return "cover"
    return "scene"


def _sanitize_image_prompt_text(text: str) -> str:
    # Replace unsafe romance-heavy wording with milder visual descriptors.
    sanitized = _normalize_spaces(text)
    for pattern, replacement in IMAGE_SAFETY_REPLACEMENTS:
        sanitized = re.sub(pattern, replacement, sanitized, flags=re.IGNORECASE)
    return _normalize_spaces(sanitized)


def _is_image_safety_block_error(exc: Exception) -> bool:
    # Detect safety-blocked image errors so the flow can retry in safe mode.
    error_body = getattr(exc, "body", None) or {}
    error_data = error_body.get("error", {}) if isinstance(error_body, dict) else {}
    error_code = str(error_data.get("code", "")).casefold()
    error_message = str(error_data.get("message", "")).casefold()
    fallback_message = str(exc).casefold()

    if error_code == "moderation_blocked":
        return True

    combined_message = f"{error_message} {fallback_message}"
    return "moderation_blocked" in combined_message or "safety_violations" in combined_message


def get_image_mime_type(output_format: str = IMAGE_OUTPUT_FORMAT) -> str:
    # Map the configured image format to the correct MIME type.
    return IMAGE_MIME_TYPES.get(output_format, "image/png")


def build_book_image_filename(message: dict, variant: str) -> str:
    # Generate a stable image filename based on the chosen title and variant.
    display = message.get("display") or {}
    title = str(display.get("recommended_title") or "smart-librarian")
    normalized = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode("ascii")
    normalized = re.sub(r"[^a-zA-Z0-9]+", "-", normalized).strip("-").lower()
    file_stem = normalized or "smart-librarian"
    return f"{file_stem}-{_get_variant_slug(variant)}.{IMAGE_OUTPUT_FORMAT}"


def build_book_image_prompt(message: dict, variant: str, *, safe_mode: bool = False) -> str:
    # Build a cover or scene prompt from the assistant recommendation payload.
    if variant not in IMAGE_VARIANTS:
        raise ValueError(f"Unsupported image variant: {variant}")

    display = message.get("display") or {}
    title = _normalize_spaces(str(display.get("recommended_title") or "Unknown title"))
    author = _normalize_spaces(str(display.get("recommended_author") or "Unknown author"))
    why_this_book = _trim_context_text(display.get("why_this_book") or message.get("content", ""))
    full_summary = _trim_context_text(display.get("full_summary") or "")
    genres = ", ".join(display.get("genres") or [])

    if safe_mode:
        title = _sanitize_image_prompt_text(title)
        author = _sanitize_image_prompt_text(author)
        why_this_book = _sanitize_image_prompt_text(why_this_book)
        full_summary = _sanitize_image_prompt_text(full_summary)
        genres = _sanitize_image_prompt_text(genres)

    shared_context_parts = [
        f"Book: {title} by {author}.",
        f"Genre context: {genres}." if genres else "",
        f"Reason for recommendation: {why_this_book}" if why_this_book else "",
        f"Summary context: {full_summary}" if full_summary else "",
    ]
    shared_context = " ".join(part for part in shared_context_parts if part).strip()

    safety_constraints = (
        "Safety constraints: keep the image non-explicit, non-sexual, tasteful, "
        "with fully clothed characters, no nudity, no lingerie, no erotic posing, "
        "no kissing focus, no bedroom context, and no graphic content.\n"
    )

    if safe_mode:
        safety_constraints += (
            "Fallback mode: if romance is implied, emphasize atmosphere, symbolism, setting, "
            "costumes, architecture, and emotional tone instead of intimacy.\n"
        )

    if variant == "cover":
        return (
            "Use case: illustration-story\n"
            "Asset type: generated book-cover concept for a recommendation app\n"
            f"Primary request: Create a polished, representative book-cover illustration inspired by {title} by {author}.\n"
            f"Visual direction: {IMAGE_STYLE}\n"
            "Style/medium: premium editorial illustration, cinematic, high-detail, visually striking\n"
            "Composition/framing: portrait composition, centered focal subject, strong silhouette, clear depth, cover-ready layout\n"
            "Typography/layout: design this as a believable printed book cover with readable, professionally typeset text already embedded in the artwork.\n"
            f'Typography requirement: include the exact title text "{title}" and the exact author text "{author}".\n'
            "Text placement: place the title and author in the upper-middle area, centered horizontally, like a real trade book cover; keep the author directly beneath the title.\n"
            "Text hierarchy: make the title dominant and much larger, while the author name is visibly smaller, secondary, and less prominent than the title.\n"
            "Text styling: keep the lettering crisp, elegant, high-contrast, correctly spelled, and clearly legible at thumbnail size.\n"
            "Lighting/mood: dramatic and evocative, matched to the book's themes\n"
            "Scene/backdrop: draw from the story world and emotional tone described below\n"
            f"{safety_constraints}"
            f"Subject: {shared_context}\n"
            "Constraints: do not add any extra text beyond the exact title and author, and do not include a watermark, logo, publisher mark, sticker, price burst, or UI elements"
        )

    return (
        "Use case: illustration-story\n"
        "Asset type: representative scene for a recommendation app\n"
        f"Primary request: Create a single cinematic scene that captures the essence of {title} by {author}.\n"
        f"Visual direction: {IMAGE_STYLE}\n"
        "Style/medium: atmospheric digital painting, rich detail, expressive characters and environment\n"
        "Composition/framing: wide landscape composition, story-driven focal point, layered depth\n"
        "Lighting/mood: immersive, emotionally aligned with the book's mood and themes\n"
        "Scene/backdrop: depict a memorable or symbolic moment suggested by the recommendation reason and summary\n"
        f"{safety_constraints}"
        f"Subject: {shared_context}\n"
        "Constraints: no readable text, no watermark, no logo, no split panels, no UI elements"
    )


def generate_book_image(message: dict, variant: str) -> dict[str, str | bytes]:
    # Generate an image, retrying with a safer prompt if moderation blocks it.
    prompt = build_book_image_prompt(message, variant)
    client = get_openai_client()

    try:
        response = client.images.generate(
            model=IMAGE_MODEL,
            prompt=prompt,
            size=_get_variant_size(variant),
            quality=IMAGE_QUALITY,
            output_format=IMAGE_OUTPUT_FORMAT,
        )
    except Exception as exc:
        if not _is_image_safety_block_error(exc):
            raise

        prompt = build_book_image_prompt(message, variant, safe_mode=True)
        response = client.images.generate(
            model=IMAGE_MODEL,
            prompt=prompt,
            size=_get_variant_size(variant),
            quality=IMAGE_QUALITY,
            output_format=IMAGE_OUTPUT_FORMAT,
        )

    image_payload = (response.data or [None])[0]
    image_b64 = getattr(image_payload, "b64_json", None) if image_payload else None
    if not image_b64:
        raise RuntimeError("Image generation did not return image bytes.")

    return {
        "image_bytes": base64.b64decode(image_b64),
        "mime_type": get_image_mime_type(IMAGE_OUTPUT_FORMAT),
        "file_name": build_book_image_filename(message, variant),
        "prompt_used": prompt,
        "variant": variant,
        "caption": (
            "Coperta generata pentru recomandare"
            if variant == "cover"
            else "Scena reprezentativa generata pentru carte"
        ),
    }

