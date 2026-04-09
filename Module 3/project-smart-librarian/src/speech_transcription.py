from io import BytesIO
import re

from src.config import STT_MODEL, STT_RESPONSE_FORMAT
from src.embeddings import get_openai_client
from src.language_support import _detect_with_langdetect, detect_user_language

DEFAULT_AUDIO_QUESTION_FILENAME = "voice-question.wav"
SUPPORTED_SPEECH_LANGUAGES = ("ro", "en")


class UnsupportedSpeechLanguageError(ValueError):
    """Raised when the spoken message is not in Romanian or English."""


def _normalize_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", (text or "")).strip()


def _build_audio_file(audio_bytes: bytes, file_name: str) -> BytesIO:
    audio_file = BytesIO(audio_bytes)
    audio_file.name = file_name
    return audio_file


def _normalize_transcription_language(preferred_language: str | None) -> str | None:
    if preferred_language in SUPPORTED_SPEECH_LANGUAGES:
        return preferred_language
    return None


def _build_transcription_language_order(preferred_language: str | None) -> list[str]:
    normalized_language = _normalize_transcription_language(preferred_language)
    if normalized_language:
        return [normalized_language, *[lang for lang in SUPPORTED_SPEECH_LANGUAGES if lang != normalized_language]]
    return list(SUPPORTED_SPEECH_LANGUAGES)


def _extract_transcript_text(response) -> str:
    transcript_text = response if isinstance(response, str) else getattr(response, "text", "")
    return _normalize_spaces(transcript_text)


def _detect_transcript_language_code(transcript_text: str) -> str | None:
    detected = _detect_with_langdetect(transcript_text)
    if detected is not None:
        detected_lang, confidence = detected
        if confidence >= 0.60:
            return detected_lang

    heuristic_language = detect_user_language(transcript_text)
    if heuristic_language in SUPPORTED_SPEECH_LANGUAGES:
        return heuristic_language

    return None


def transcribe_audio_bytes(
    audio_bytes: bytes,
    *,
    file_name: str = DEFAULT_AUDIO_QUESTION_FILENAME,
    preferred_language: str | None = None,
) -> str:
    if not audio_bytes:
        raise ValueError("Nu exista continut audio pentru transcriere.")

    client = get_openai_client()
    fallback_transcript = ""

    for language in _build_transcription_language_order(preferred_language):
        response = client.audio.transcriptions.create(
            model=STT_MODEL,
            file=_build_audio_file(audio_bytes, file_name),
            response_format=STT_RESPONSE_FORMAT,
            language=language,
        )

        normalized_transcript = _extract_transcript_text(response)
        if not normalized_transcript:
            continue

        detected_language = _detect_transcript_language_code(normalized_transcript)
        if detected_language not in SUPPORTED_SPEECH_LANGUAGES:
            continue

        if detected_language == language:
            return normalized_transcript

        if not fallback_transcript:
            fallback_transcript = normalized_transcript

    if not fallback_transcript:
        raise UnsupportedSpeechLanguageError(
            "Mesajul vocal trebuie sa fie doar in romana sau engleza."
        )

    return fallback_transcript


def transcribe_uploaded_audio(uploaded_audio, *, preferred_language: str | None = None) -> str:
    if uploaded_audio is None:
        raise ValueError("Nu exista fisier audio de transcris.")

    file_name = getattr(uploaded_audio, "name", DEFAULT_AUDIO_QUESTION_FILENAME)
    if hasattr(uploaded_audio, "getvalue"):
        audio_bytes = uploaded_audio.getvalue()
    else:
        audio_bytes = uploaded_audio.read()

    return transcribe_audio_bytes(
        audio_bytes,
        file_name=file_name,
        preferred_language=preferred_language,
    )
