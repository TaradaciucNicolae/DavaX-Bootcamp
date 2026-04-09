from types import SimpleNamespace

from src.audio_narration import (
    build_audio_filename,
    build_audio_narration_text,
    generate_audio_narration,
)


def _assistant_message(language: str = "ro") -> dict:
    return {
        "role": "assistant",
        "kind": "assistant",
        "response_language": language,
        "content": "Mesaj fallback",
        "display": {
            "recommended_title": "1984",
            "recommended_author": "George Orwell",
            "why_this_book": "Se potriveste pentru teme despre libertate si control social.",
            "full_summary": "Un roman distopic despre supraveghere, propaganda si rezistenta.",
        },
    }


def test_build_audio_narration_text_in_romanian():
    narration = build_audio_narration_text(_assistant_message("ro"))

    assert narration.startswith("Se potriveste pentru teme despre libertate si control social.")
    assert "Rezumat complet:" in narration


def test_build_audio_narration_text_in_english():
    narration = build_audio_narration_text(_assistant_message("en"))

    assert narration.startswith("Se potriveste pentru teme despre libertate si control social.")
    assert "Full summary:" in narration


def test_build_audio_narration_text_for_summary_only_reads_only_full_summary():
    message = _assistant_message("ro")
    message["kind"] = "summary_only"

    narration = build_audio_narration_text(message)

    assert narration == "Un roman distopic despre supraveghere, propaganda si rezistenta."


def test_build_audio_filename_uses_recommended_title_slug():
    filename = build_audio_filename(_assistant_message("ro"), response_format="mp3")

    assert filename == "1984.mp3"


def test_generate_audio_narration_returns_audio_payload(monkeypatch):
    captured_kwargs = {}

    class DummySpeechApi:
        def create(self, **kwargs):
            captured_kwargs.update(kwargs)
            return SimpleNamespace(content=b"audio-bytes")

    class DummyClient:
        def __init__(self):
            self.audio = SimpleNamespace(speech=DummySpeechApi())

    monkeypatch.setattr("src.audio_narration.get_openai_client", lambda: DummyClient())
    monkeypatch.setattr("src.audio_narration.TTS_MODEL", "gpt-4o-mini-tts")
    monkeypatch.setattr("src.audio_narration.TTS_VOICE", "alloy")
    monkeypatch.setattr("src.audio_narration.TTS_RESPONSE_FORMAT", "mp3")

    result = generate_audio_narration(_assistant_message("ro"))

    assert result["audio_bytes"] == b"audio-bytes"
    assert result["mime_type"] == "audio/mp3"
    assert result["file_name"] == "1984.mp3"
    assert captured_kwargs["model"] == "gpt-4o-mini-tts"
    assert captured_kwargs["voice"] == "alloy"
    assert captured_kwargs["response_format"] == "mp3"
    assert captured_kwargs["input"].startswith("Se potriveste pentru teme despre libertate si control social.")
