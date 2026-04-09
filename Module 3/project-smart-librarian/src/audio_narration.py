# Script for turning assistant messages into downloadable TTS narration.

import re
import unicodedata

from src.config import TTS_MODEL, TTS_RESPONSE_FORMAT, TTS_VOICE
from src.embeddings import get_openai_client

MAX_TTS_INPUT_CHARS = 4000
DEFAULT_AUDIO_FILENAME = "smart-librarian-recommendation"
AUDIO_MIME_TYPES = {
    "mp3": "audio/mp3",
    "opus": "audio/ogg",
    "aac": "audio/aac",
    "flac": "audio/flac",
    "wav": "audio/wav",
    "pcm": "audio/pcm",
}


def _normalize_spaces(text: str) -> str:
    # Collapse repeated whitespace before narration text is assembled.
    return re.sub(r"\s+", " ", (text or "")).strip()


def _trim_tts_text(text: str, max_chars: int = MAX_TTS_INPUT_CHARS) -> str:
    # Trim narration text to the service limit without cutting too abruptly.
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

    if last_break >= int(max_chars * 0.65):
        return truncated_text[: last_break + 1].strip()

    last_space = truncated_text.rfind(" ")
    if last_space > 0:
        return truncated_text[:last_space].strip()

    return truncated_text


def build_audio_narration_text(message: dict) -> str:
    # Build the spoken text based on the message kind and response language.
    language = message.get("response_language", "ro")
    kind = message.get("kind", "assistant")
    display = message.get("display") or {}
    fallback_content = _normalize_spaces(message.get("content", ""))

    if not display:
        return _trim_tts_text(fallback_content)

    why_this_book = _normalize_spaces(display.get("why_this_book") or fallback_content)
    full_summary = _normalize_spaces(display.get("full_summary") or "")

    if kind == "summary_only":
        return _trim_tts_text(full_summary or fallback_content)

    if language == "en":
        parts = [
            why_this_book,
            f"Full summary: {full_summary}" if full_summary else "",
        ]
        return _trim_tts_text(" ".join(part for part in parts if part))

    parts = [
        why_this_book,
        f"Rezumat complet: {full_summary}" if full_summary else "",
    ]
    return _trim_tts_text(" ".join(part for part in parts if part))


def get_audio_mime_type(response_format: str = TTS_RESPONSE_FORMAT) -> str:
    # Map the configured TTS format to a browser-friendly MIME type.
    return AUDIO_MIME_TYPES.get(response_format, "audio/mp3")


def build_audio_filename(message: dict, response_format: str = TTS_RESPONSE_FORMAT) -> str:
    # Generate a stable download filename based on the recommended title.
    display = message.get("display") or {}
    title = str(display.get("recommended_title") or DEFAULT_AUDIO_FILENAME)
    normalized = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode("ascii")
    normalized = re.sub(r"[^a-zA-Z0-9]+", "-", normalized).strip("-").lower()
    file_stem = normalized or DEFAULT_AUDIO_FILENAME
    extension = response_format or "mp3"
    return f"{file_stem}.{extension}"


def generate_audio_narration(message: dict) -> dict[str, str | bytes]:
    # Call OpenAI TTS and return the payload needed by the Streamlit UI.
    narration_text = build_audio_narration_text(message)
    if not narration_text:
        raise ValueError("Nu exista text disponibil pentru generarea audio.")

    client = get_openai_client()
    response = client.audio.speech.create(
        model=TTS_MODEL,
        voice=TTS_VOICE,
        response_format=TTS_RESPONSE_FORMAT,
        input=narration_text,
    )

    return {
        "audio_bytes": response.content,
        "mime_type": get_audio_mime_type(TTS_RESPONSE_FORMAT),
        "file_name": build_audio_filename(message, TTS_RESPONSE_FORMAT),
        "narration_text": narration_text,
    }

