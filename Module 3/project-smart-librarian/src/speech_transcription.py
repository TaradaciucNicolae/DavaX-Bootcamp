# Speech-to-text helpers for Romanian and English voice input.

from io import BytesIO
from pathlib import Path
import re

from src.config import STT_MODEL, STT_RESPONSE_FORMAT
from src.embeddings import get_openai_client
from src.language_support import _detect_with_langdetect, detect_user_language
from src.logger import configure_logging

logger = configure_logging()

DEFAULT_AUDIO_QUESTION_FILENAME = "voice-question.wav"
SUPPORTED_SPEECH_LANGUAGES = ("ro", "en")
SUPPORTED_AUDIO_EXTENSIONS = {".wav", ".webm", ".mp3", ".m4a", ".mp4", ".mpeg", ".mpga"}
MIME_TYPE_TO_EXTENSION = {
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/webm": ".webm",
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".mp4",
    "audio/x-m4a": ".m4a",
    "audio/m4a": ".m4a",
}


class UnsupportedSpeechLanguageError(ValueError):
    # Raised when the spoken message is not in Romanian or English
    pass


def _normalize_spaces(text: str) -> str:
    # Collapse repeated whitespace in transcribed text.
    return re.sub(r"\s+", " ", (text or "")).strip()


def _build_audio_file(audio_bytes: bytes, file_name: str) -> BytesIO:
    # Wrap raw audio bytes into a file-like object accepted by the SDK.
    audio_file = BytesIO(audio_bytes)
    audio_file.name = file_name
    return audio_file


def _normalize_audio_file_name(file_name: str | None, mime_type: str | None = None) -> str:
    # Ensure the uploaded voice note keeps a valid filename and extension.
    normalized_name = (file_name or "").strip()
    suffix = Path(normalized_name).suffix.casefold()
    if suffix in SUPPORTED_AUDIO_EXTENSIONS:
        return normalized_name

    inferred_extension = MIME_TYPE_TO_EXTENSION.get((mime_type or "").casefold(), ".wav")
    stem = Path(normalized_name).stem or "voice-question"
    return f"{stem}{inferred_extension}"


def _normalize_transcription_language(preferred_language: str | None) -> str | None:
    # Keep only supported preferred languages accepted by the transcription flow.
    if preferred_language in SUPPORTED_SPEECH_LANGUAGES:
        return preferred_language
    return None


def _build_transcription_language_order(preferred_language: str | None) -> list[str]:
    # Try the preferred language first, then the remaining supported fallback.
    normalized_language = _normalize_transcription_language(preferred_language)
    if normalized_language:
        return [normalized_language, *[lang for lang in SUPPORTED_SPEECH_LANGUAGES if lang != normalized_language]]
    return list(SUPPORTED_SPEECH_LANGUAGES)


def _extract_transcript_text(response) -> str:
    # Read normalized transcript text from SDK responses or plain strings.
    if isinstance(response, str):
        transcript_text = response
    elif isinstance(response, dict):
        transcript_text = (
            response.get("text")
            or response.get("output_text")
            or response.get("transcript")
            or ""
        )
    else:
        transcript_text = (
            getattr(response, "text", None)
            or getattr(response, "output_text", None)
            or getattr(response, "transcript", None)
            or ""
        )
    return _normalize_spaces(transcript_text)


def _build_transcription_request_kwargs(
    audio_bytes: bytes,
    *,
    file_name: str,
    language: str | None,
) -> dict:
    # Build one SDK transcription request, omitting the language when auto-detecting.
    request_kwargs = {
        "model": STT_MODEL,
        "file": _build_audio_file(audio_bytes, file_name),
        "response_format": STT_RESPONSE_FORMAT,
    }
    if language:
        request_kwargs["language"] = language
    return request_kwargs


def _detect_transcript_language_code(transcript_text: str) -> str | None:
    # Detect the language of the returned transcript before accepting it.
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
    # Transcribe raw audio bytes while keeping the language restricted to ro/en.
    if not audio_bytes:
        raise ValueError("Nu exista continut audio pentru transcriere.")

    client = get_openai_client()
    fallback_transcript = ""
    normalized_file_name = _normalize_audio_file_name(file_name)
    language_attempts = [* _build_transcription_language_order(preferred_language), None]
    logger.info(
        "voice_transcription_request_started | bytes=%s | file_name=%s | preferred_language=%s | attempt_count=%s",
        len(audio_bytes),
        normalized_file_name,
        preferred_language,
        len(language_attempts),
    )

    for language in language_attempts:
        requested_language = language or "auto"
        logger.info(
            "voice_transcription_attempt | file_name=%s | requested_language=%s",
            normalized_file_name,
            requested_language,
        )
        response = client.audio.transcriptions.create(
            **_build_transcription_request_kwargs(
                audio_bytes,
                file_name=normalized_file_name,
                language=language,
            )
        )

        normalized_transcript = _extract_transcript_text(response)
        if not normalized_transcript:
            logger.warning(
                "voice_transcription_empty_response | file_name=%s | requested_language=%s",
                normalized_file_name,
                requested_language,
            )
            continue

        detected_language = _detect_transcript_language_code(normalized_transcript)
        if detected_language not in SUPPORTED_SPEECH_LANGUAGES:
            logger.warning(
                "voice_transcription_language_rejected | file_name=%s | requested_language=%s | detected_language=%s | transcript_chars=%s",
                normalized_file_name,
                requested_language,
                detected_language or "unknown",
                len(normalized_transcript),
            )
            continue

        if language is None or detected_language == language:
            logger.info(
                "voice_transcription_response_accepted | file_name=%s | requested_language=%s | detected_language=%s | transcript_chars=%s",
                normalized_file_name,
                requested_language,
                detected_language,
                len(normalized_transcript),
            )
            return normalized_transcript

        if not fallback_transcript:
            fallback_transcript = normalized_transcript
            logger.info(
                "voice_transcription_fallback_buffered | file_name=%s | requested_language=%s | detected_language=%s | transcript_chars=%s",
                normalized_file_name,
                requested_language,
                detected_language,
                len(normalized_transcript),
            )

    if not fallback_transcript:
        logger.warning(
            "voice_transcription_no_supported_result | file_name=%s | preferred_language=%s",
            normalized_file_name,
            preferred_language,
        )
        raise UnsupportedSpeechLanguageError(
            "Mesajul vocal trebuie sa fie doar in romana sau engleza."
        )

    logger.info(
        "voice_transcription_returning_fallback | file_name=%s | transcript_chars=%s",
        normalized_file_name,
        len(fallback_transcript),
    )
    return fallback_transcript


def transcribe_uploaded_audio(uploaded_audio, *, preferred_language: str | None = None) -> str:
    # Read bytes from a Streamlit upload-like object and transcribe them.
    if uploaded_audio is None:
        raise ValueError("Nu exista fisier audio de transcris.")

    file_name = _normalize_audio_file_name(
        getattr(uploaded_audio, "name", DEFAULT_AUDIO_QUESTION_FILENAME),
        getattr(uploaded_audio, "type", None),
    )
    if hasattr(uploaded_audio, "getvalue"):
        audio_bytes = uploaded_audio.getvalue()
    else:
        audio_bytes = uploaded_audio.read()

    logger.info(
        "voice_uploaded_audio_loaded | bytes=%s | original_name=%s | normalized_name=%s | mime=%s | preferred_language=%s",
        len(audio_bytes),
        getattr(uploaded_audio, "name", DEFAULT_AUDIO_QUESTION_FILENAME),
        file_name,
        getattr(uploaded_audio, "type", ""),
        preferred_language,
    )

    return transcribe_audio_bytes(
        audio_bytes,
        file_name=file_name,
        preferred_language=preferred_language,
    )
