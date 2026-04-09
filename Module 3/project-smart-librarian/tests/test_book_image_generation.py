# Tests for image prompt creation and generated-image payload handling.

import base64
from types import SimpleNamespace

from src.book_image_generation import (
    build_book_image_filename,
    build_book_image_prompt,
    generate_book_image,
)


def _assistant_message() -> dict:
    # Create a representative assistant payload used across image tests.
    return {
        "role": "assistant",
        "kind": "assistant",
        "response_language": "ro",
        "content": "Mesaj fallback",
        "display": {
            "recommended_title": "The Hobbit",
            "recommended_author": "J.R.R. Tolkien",
            "why_this_book": "Se potriveste datorita aventurii, curajului si atmosferei fantastice.",
            "full_summary": (
                "Bilbo porneste intr-o calatorie plina de pericole, creaturi fantastice "
                "si momente care ii testeaza curajul."
            ),
        },
    }


def test_build_book_image_prompt_for_cover():
    prompt = build_book_image_prompt(_assistant_message(), "cover")

    assert "book-cover concept" in prompt
    assert "The Hobbit by J.R.R. Tolkien" in prompt
    assert "Visual direction:" in prompt
    assert 'include the exact title text "The Hobbit"' in prompt
    assert 'the exact author text "J.R.R. Tolkien"' in prompt
    assert "upper-middle area" in prompt
    assert "author name is visibly smaller" in prompt
    assert "do not add any extra text" in prompt
    assert "fully clothed characters" in prompt


def test_build_book_image_prompt_for_scene():
    prompt = build_book_image_prompt(_assistant_message(), "scene")

    assert "representative scene" in prompt
    assert "wide landscape composition" in prompt
    assert "The Hobbit by J.R.R. Tolkien" in prompt
    assert "no readable text" in prompt


def test_build_book_image_filename_uses_title_and_variant():
    file_name = build_book_image_filename(_assistant_message(), "cover")

    assert file_name == "the-hobbit-cover.png"


def test_generate_book_image_returns_decoded_bytes(monkeypatch):
    image_bytes = b"fake-image-bytes"
    encoded_image = base64.b64encode(image_bytes).decode("ascii")
    captured_kwargs = {}

    class DummyImagesApi:
        def generate(self, **kwargs):
            captured_kwargs.update(kwargs)
            return SimpleNamespace(
                data=[SimpleNamespace(b64_json=encoded_image, revised_prompt=None)]
            )

    class DummyClient:
        def __init__(self):
            self.images = DummyImagesApi()

    monkeypatch.setattr("src.book_image_generation.get_openai_client", lambda: DummyClient())
    monkeypatch.setattr("src.book_image_generation.IMAGE_MODEL", "gpt-image-1-mini")
    monkeypatch.setattr("src.book_image_generation.IMAGE_OUTPUT_FORMAT", "png")
    monkeypatch.setattr("src.book_image_generation.IMAGE_QUALITY", "medium")
    monkeypatch.setattr("src.book_image_generation.IMAGE_STYLE", "vivid")
    monkeypatch.setattr("src.book_image_generation.IMAGE_COVER_SIZE", "1024x1536")

    result = generate_book_image(_assistant_message(), "cover")

    assert result["image_bytes"] == image_bytes
    assert result["mime_type"] == "image/png"
    assert result["file_name"] == "the-hobbit-cover.png"
    assert captured_kwargs["model"] == "gpt-image-1-mini"
    assert captured_kwargs["size"] == "1024x1536"
    assert "style" not in captured_kwargs


def test_generate_book_image_retries_with_safer_prompt_after_safety_block(monkeypatch):
    image_bytes = b"safe-image"
    encoded_image = base64.b64encode(image_bytes).decode("ascii")
    prompts = []

    class FakeSafetyError(Exception):
        def __init__(self):
            self.body = {
                "error": {
                    "code": "moderation_blocked",
                    "message": "safety_violations=[sexual]",
                }
            }
            super().__init__("moderation_blocked")

    romance_message = _assistant_message()
    romance_message["display"]["recommended_title"] = "My Scandalous Bride"
    romance_message["display"]["genres"] = ["Romance", "Drama"]
    romance_message["display"]["full_summary"] = (
        "A scandalous bride becomes involved in an intense romance full of desire."
    )

    class DummyImagesApi:
        def __init__(self):
            self.calls = 0

        def generate(self, **kwargs):
            self.calls += 1
            prompts.append(kwargs["prompt"])
            if self.calls == 1:
                raise FakeSafetyError()
            return SimpleNamespace(data=[SimpleNamespace(b64_json=encoded_image)])

    class DummyClient:
        def __init__(self):
            self.images = DummyImagesApi()

    monkeypatch.setattr("src.book_image_generation.get_openai_client", lambda: DummyClient())

    result = generate_book_image(romance_message, "cover")

    assert result["image_bytes"] == image_bytes
    assert len(prompts) == 2
    assert "My Scandalous Bride" in prompts[0]
    assert "dramatic" in prompts[1].casefold()
    assert "fully clothed characters" in prompts[1]

