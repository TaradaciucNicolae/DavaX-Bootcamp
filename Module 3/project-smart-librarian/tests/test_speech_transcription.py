from types import SimpleNamespace

import pytest

from src.speech_transcription import (
    UnsupportedSpeechLanguageError,
    transcribe_audio_bytes,
    transcribe_uploaded_audio,
)


def test_transcribe_audio_bytes_returns_normalized_text(monkeypatch):
    captured_calls = []

    class DummyTranscriptionsApi:
        def create(self, **kwargs):
            captured_calls.append(kwargs)
            return SimpleNamespace(text="  Vreau   o carte despre magie.  ")

    class DummyClient:
        def __init__(self):
            self.audio = SimpleNamespace(transcriptions=DummyTranscriptionsApi())

    monkeypatch.setattr("src.speech_transcription.get_openai_client", lambda: DummyClient())
    monkeypatch.setattr("src.speech_transcription.STT_MODEL", "gpt-4o-mini-transcribe")
    monkeypatch.setattr("src.speech_transcription.STT_RESPONSE_FORMAT", "text")

    transcript = transcribe_audio_bytes(
        b"fake-audio",
        file_name="question.wav",
        preferred_language="ro",
    )

    assert transcript == "Vreau o carte despre magie."
    assert captured_calls[0]["model"] == "gpt-4o-mini-transcribe"
    assert captured_calls[0]["response_format"] == "text"
    assert captured_calls[0]["language"] == "ro"
    assert captured_calls[0]["file"].name == "question.wav"
    assert captured_calls[0]["file"].read() == b"fake-audio"


def test_transcribe_uploaded_audio_uses_uploaded_file_name(monkeypatch):
    captured_calls = []

    def _fake_transcribe_audio_bytes(audio_bytes, *, file_name, preferred_language):
        captured_calls.append((audio_bytes, file_name, preferred_language))
        return "Transcript gata"

    uploaded_audio = SimpleNamespace(
        name="spoken-question.webm",
        getvalue=lambda: b"webm-bytes",
    )

    monkeypatch.setattr("src.speech_transcription.transcribe_audio_bytes", _fake_transcribe_audio_bytes)

    transcript = transcribe_uploaded_audio(uploaded_audio, preferred_language="en")

    assert transcript == "Transcript gata"
    assert captured_calls == [(b"webm-bytes", "spoken-question.webm", "en")]


def test_transcribe_audio_bytes_retries_with_other_supported_language(monkeypatch):
    captured_languages = []
    responses = iter(
        [
            SimpleNamespace(text="recommend me something about dragons"),
            SimpleNamespace(text="recommend me something about dragons"),
        ]
    )

    class DummyTranscriptionsApi:
        def create(self, **kwargs):
            captured_languages.append(kwargs["language"])
            return next(responses)

    class DummyClient:
        def __init__(self):
            self.audio = SimpleNamespace(transcriptions=DummyTranscriptionsApi())

    monkeypatch.setattr("src.speech_transcription.get_openai_client", lambda: DummyClient())
    monkeypatch.setattr("src.speech_transcription.STT_MODEL", "gpt-4o-mini-transcribe")
    monkeypatch.setattr("src.speech_transcription.STT_RESPONSE_FORMAT", "text")

    transcript = transcribe_audio_bytes(
        b"fake-audio",
        file_name="question.wav",
        preferred_language="ro",
    )

    assert transcript == "recommend me something about dragons"
    assert captured_languages == ["ro", "en"]


def test_transcribe_audio_bytes_rejects_unsupported_language(monkeypatch):
    class DummyTranscriptionsApi:
        def create(self, **kwargs):
            return SimpleNamespace(text="Quiero una novela sobre amistad")

    class DummyClient:
        def __init__(self):
            self.audio = SimpleNamespace(transcriptions=DummyTranscriptionsApi())

    monkeypatch.setattr("src.speech_transcription.get_openai_client", lambda: DummyClient())
    monkeypatch.setattr("src.speech_transcription.STT_MODEL", "gpt-4o-mini-transcribe")
    monkeypatch.setattr("src.speech_transcription.STT_RESPONSE_FORMAT", "text")
    monkeypatch.setattr(
        "src.speech_transcription._detect_transcript_language_code",
        lambda _text: "es",
    )

    with pytest.raises(UnsupportedSpeechLanguageError):
        transcribe_audio_bytes(
            b"fake-audio",
            file_name="question.wav",
            preferred_language="ro",
        )
