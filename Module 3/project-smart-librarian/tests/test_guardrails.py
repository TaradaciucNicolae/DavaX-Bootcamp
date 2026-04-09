from pathlib import Path
from uuid import uuid4

from src.guardrails import (
    find_blocked_terms,
    infer_book_query_from_preference,
    is_book_related_query,
    normalize_book_query_aliases,
    normalize_user_text,
    validate_user_query,
)


def test_normalize_user_text_reduces_spaces():
    result = normalize_user_text("  salut     lume   ")
    assert result == "salut lume"


def test_empty_input_is_blocked():
    result = validate_user_query("   ")
    assert result.is_allowed is False
    assert "gol" in result.reason.lower()


def test_romanian_offensive_input_is_blocked_from_txt():
    result = validate_user_query("Esti prost")
    assert result.is_allowed is False
    assert "fara limbaj ofensator" in result.reason.lower()
    assert "prost" in result.matched_terms


def test_english_offensive_input_is_blocked_from_txt():
    result = validate_user_query("You are stupid")
    assert result.is_allowed is False
    assert "fara limbaj ofensator" in result.reason.lower()
    assert "stupid" in result.matched_terms


def test_filter_does_not_block_sf_abbreviation():
    result = validate_user_query("iubesc SF")
    assert result.is_allowed is True
    assert result.matched_terms == []


def test_filter_does_not_block_normal_fantasy_question():
    result = validate_user_query("Ce-mi recomanzi daca iubesc povestile fantastice?")
    assert result.is_allowed is True
    assert result.matched_terms == []


def test_filter_does_not_block_sci_fi_phrase():
    result = validate_user_query("I love sci-fi books")
    assert result.is_allowed is True
    assert result.matched_terms == []


def test_filter_uses_terms_from_both_language_files(monkeypatch):
    custom_ro_file = Path("tests") / f"blocked_terms_ro_{uuid4().hex}.txt"
    custom_en_file = Path("tests") / f"blocked_terms_en_{uuid4().hex}.txt"

    try:
        custom_ro_file.write_text(
            "# comentariu\ntermen_personalizat\n",
            encoding="utf-8",
        )
        custom_en_file.write_text(
            "# comment\nshut up\n",
            encoding="utf-8",
        )

        monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_RO_FILE", custom_ro_file)
        monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_EN_FILE", custom_en_file)

        safe_result = validate_user_query("Ai un mesaj complet sigur")
        assert safe_result.is_allowed is True

        ro_result = validate_user_query("Esti termen_personalizat")
        assert ro_result.is_allowed is False
        assert ro_result.matched_terms == ["termen personalizat"]

        en_result = validate_user_query("Please shut up now")
        assert en_result.is_allowed is False
        assert en_result.matched_terms == ["shut up"]
    finally:
        if custom_ro_file.exists():
            custom_ro_file.unlink()
        if custom_en_file.exists():
            custom_en_file.unlink()


def test_filter_is_diacritic_insensitive_for_custom_terms(monkeypatch):
    custom_ro_file = Path("tests") / f"blocked_terms_ro_{uuid4().hex}.txt"
    custom_en_file = Path("tests") / f"blocked_terms_en_{uuid4().hex}.txt"

    try:
        custom_ro_file.write_text("nesimtit\n", encoding="utf-8")
        custom_en_file.write_text("", encoding="utf-8")

        monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_RO_FILE", custom_ro_file)
        monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_EN_FILE", custom_en_file)

        result = validate_user_query("Esti nesimțit")
        assert result.is_allowed is False
        assert "nesimtit" in result.matched_terms
    finally:
        if custom_ro_file.exists():
            custom_ro_file.unlink()
        if custom_en_file.exists():
            custom_en_file.unlink()


def test_find_blocked_terms_returns_empty_when_sources_are_empty(monkeypatch):
    missing_ro_file = Path("tests") / f"missing_ro_{uuid4().hex}.txt"
    missing_en_file = Path("tests") / f"missing_en_{uuid4().hex}.txt"
    monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_RO_FILE", missing_ro_file)
    monkeypatch.setattr("src.guardrails.BLOCKED_TERMS_EN_FILE", missing_en_file)

    assert find_blocked_terms("Esti orice") == []


def test_clean_input_is_allowed():
    result = validate_user_query("Vreau o carte despre magie si prietenie.")
    assert result.is_allowed is True
    assert result.cleaned_text == "Vreau o carte despre magie si prietenie."


def test_scope_detection_accepts_known_title_query():
    assert is_book_related_query("Ce este 1984?") is True


def test_scope_detection_accepts_recommendation_with_theme():
    assert is_book_related_query("Ce-mi recomanzi daca iubesc povestile fantastice?") is True


def test_scope_detection_accepts_mystery_genre_typo():
    assert is_book_related_query("vreau ceva cu mistery") is True


def test_normalize_book_query_aliases_fixes_mystery_typo():
    assert normalize_book_query_aliases("vreau ceva cu mistery") == "vreau ceva cu mystery"


def test_infer_book_query_from_romanian_preference_fragment():
    inferred = infer_book_query_from_preference("imi place pompierii", "ro")
    assert inferred == "Vreau o carte despre pompierii."


def test_infer_book_query_from_english_preference_fragment():
    inferred = infer_book_query_from_preference("I like firefighters", "en")
    assert inferred == "I want a book about firefighters."


def test_scope_detection_rejects_unrelated_question():
    assert is_book_related_query("Cum va fi vremea maine la Bucuresti?") is False
