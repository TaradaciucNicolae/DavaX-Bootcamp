# Language detection and translation helpers for bilingual UX output.

import re
from typing import Any

from src.config import LLM_MODEL

try:
    from langdetect import DetectorFactory, detect_langs
    from langdetect.lang_detect_exception import LangDetectException

    DetectorFactory.seed = 0
except ImportError:
    detect_langs = None
    LangDetectException = Exception

ROMANIAN_DIACRITICS = set("ăâîșşțţ")

ROMANIAN_MARKERS = {
    "a",
    "ai",
    "am",
    "as",
    "aș",
    "carti",
    "carte",
    "cartile",
    "ce",
    "ceva",
    "cineva",
    "control",
    "cum",
    "cu",
    "daca",
    "dacă",
    "da-mi",
    "dami",
    "de",
    "despre",
    "ador",
    "este",
    "fantastice",
    "gen",
    "imi",
    "îmi",
    "intrebare",
    "întrebare",
    "iubesc",
    "la",
    "libertate",
    "mai",
    "maine",
    "mi",
    "pentru",
    "poveste",
    "povesti",
    "povești",
    "recomanda",
    "recomanda-mi",
    "recomanzi",
    "rezumat",
    "roman",
    "sau",
    "si",
    "sunt",
    "te",
    "tema",
    "tragica",
    "trista",
    "trist",
    "un",
    "vremea",
    "vreau",
    "vreo",
    "sf",
}

ENGLISH_MARKERS = {
    "a",
    "about",
    "and",
    "book",
    "books",
    "for",
    "freedom",
    "give",
    "is",
    "love",
    "me",
    "or",
    "recommend",
    "someone",
    "stories",
    "summary",
    "the",
    "want",
    "what",
}

ROMANIAN_PATTERNS = (
    r"\b(?:da-?mi|spune-?mi|recomanda-?mi|ce-?mi)\b",
    r"\b(?:imi|îmi|mi|ma|mă)\b",
    r"\b(?:carti|cărți|carte|cărți)\b",
)

ENGLISH_PATTERNS = (
    r"\b(?:give me|tell me|recommend me)\b",
    r"\b(?:book|books|summary)\b",
)


def _tokenize(text: str) -> list[str]:
    # Tokenize a short user message with a lightweight regex strategy.
    return re.findall(r"\b[\w'-]+\b", text.casefold())


def _score_markers(text: str, tokens: list[str], markers: set[str], patterns: tuple[str, ...]) -> int:
    # Score heuristic language markers before falling back to langdetect.
    score = 0
    score += sum(token in markers for token in tokens)
    score += sum(bool(re.search(pattern, text)) * 2 for pattern in patterns)
    return score


def _detect_with_langdetect(text: str) -> tuple[str, float] | None:
    # Use langdetect when available and return `(language, confidence)`.
    if detect_langs is None:
        return None

    try:
        candidates = detect_langs(text)
    except LangDetectException:
        return None

    if not candidates:
        return None

    top = candidates[0]
    return top.lang, float(top.prob)


def detect_user_language(text: str) -> str:
    # Detect whether the user message is better treated as Romanian or English.
    lowered_text = text.strip().casefold()
    if not lowered_text:
        return "en"

    if any(char in ROMANIAN_DIACRITICS for char in lowered_text):
        return "ro"

    tokens = _tokenize(lowered_text)
    romanian_score = _score_markers(
        lowered_text,
        tokens,
        ROMANIAN_MARKERS,
        ROMANIAN_PATTERNS,
    )
    english_score = _score_markers(
        lowered_text,
        tokens,
        ENGLISH_MARKERS,
        ENGLISH_PATTERNS,
    )

    if len(tokens) <= 4:
        if romanian_score >= 1 and english_score == 0:
            return "ro"
        if english_score >= 1 and romanian_score == 0:
            return "en"

    detected = _detect_with_langdetect(lowered_text)
    if detected is not None:
        detected_lang, confidence = detected

        if detected_lang == "ro" and confidence >= 0.60:
            return "ro"
        if detected_lang == "en" and confidence >= 0.60 and english_score >= romanian_score:
            return "en"

    if romanian_score > english_score:
        return "ro"

    return "en"


def get_language_name(language_code: str) -> str:
    # Return the human-readable language name used in prompts.
    if language_code == "ro":
        return "Romanian"
    return "English"


def should_translate_text(text: str, target_language: str) -> bool:
    # Decide whether a model or tool output should be translated.
    if not text.strip():
        return False
    return detect_user_language(text) != target_language


def translate_text(client: Any, text: str, target_language: str) -> str:
    # Translate arbitrary text with the main OpenAI text model.
    response = client.responses.create(
        model=LLM_MODEL,
        instructions=(
            "You are a precise translator. Translate the text faithfully into the target language. "
            "Preserve book titles, author names, and meaning. Return only the translated text."
        ),
        input=(
            f"Target language: {get_language_name(target_language)}\n\n"
            f"Text to translate:\n{text}"
        ),
    )
    return (getattr(response, "output_text", None) or "").strip()


def translate_text_if_needed(client: Any, text: str, target_language: str) -> str:
    # Translate only when detection says the text is in another language.
    if not should_translate_text(text, target_language):
        return text

    translated = translate_text(client, text, target_language)
    return translated or text


def normalize_text_to_target_language(client: Any, text: str, target_language: str) -> str:
    # Normalize final user-visible text into the expected language.
    if not text.strip():
        return text

    # Romanian output is forced through translation to avoid mixed-language answers
    # or Romanian text that silently drifts into plain English.
    if target_language == "ro":
        translated = translate_text(client, text, target_language)
        return translated or text

    return translate_text_if_needed(client, text, target_language)

