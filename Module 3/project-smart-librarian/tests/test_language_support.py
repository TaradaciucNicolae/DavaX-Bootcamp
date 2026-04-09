from src.language_support import detect_user_language, normalize_text_to_target_language


def test_detect_user_language_identifies_romanian_without_diacritics():
    queries = [
        "Vreau o carte despre libertate si control social.",
        "Ce-mi recomanzi daca iubesc povestile fantastice?",
        "Da-mi o carte SF",
        "carti sf",
        "imi recomanzi ceva trist",
        "ador pompierii",
    ]

    for query in queries:
        assert detect_user_language(query) == "ro"


def test_detect_user_language_identifies_english_queries():
    queries = [
        "I want a book about freedom and surveillance.",
        "What do you recommend for someone who loves fantasy stories?",
        "Give me a sci-fi book",
    ]

    for query in queries:
        assert detect_user_language(query) == "en"


def test_normalize_text_to_target_language_forces_romanian(monkeypatch):
    monkeypatch.setattr(
        "src.language_support.translate_text",
        lambda client, text, target_language: f"[{target_language}] {text}",
    )

    result = normalize_text_to_target_language(
        client=None,
        text="I recommend 1984 by George Orwell.",
        target_language="ro",
    )

    assert result == "[ro] I recommend 1984 by George Orwell."
