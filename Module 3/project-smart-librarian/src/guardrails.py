# Local guardrails for profanity filtering and domain scoping.

import re
import unicodedata
from dataclasses import asdict, dataclass
from functools import lru_cache
from pathlib import Path

from src.config import (
    BLOCKED_TERMS_EN_FILE,
    BLOCKED_TERMS_RO_FILE,
    DATA_FILE,
    ENABLE_INPUT_FILTER,
    MAX_USER_QUERY_CHARS,
)
from src.data_loader import load_books


@dataclass
class GuardrailResult:
    # Structured validation result returned before any OpenAI calls are made.

    is_allowed: bool
    cleaned_text: str
    reason: str | None = None
    matched_terms: list[str] | None = None

    def to_dict(self) -> dict:
        return asdict(self)


BOOK_OBJECT_MARKERS = {
    "book",
    "books",
    "novel",
    "novels",
    "author",
    "authors",
    "read",
    "reading",
    "summary",
    "summaries",
    "genre",
    "genres",
    "theme",
    "themes",
    "title",
    "titles",
    "recommend",
    "recommendation",
    "recommendations",
    "fiction",
    "literature",
    "carte",
    "carti",
    "roman",
    "romane",
    "autor",
    "autori",
    "citit",
    "citesc",
    "citesti",
    "citeste",
    "rezumat",
    "rezumate",
    "gen",
    "genuri",
    "tema",
    "teme",
    "titlu",
    "titluri",
    "recomandare",
    "recomandari",
    "recomanzi",
    "recomanda",
    "literatura",
}

RECOMMENDATION_INTENT_MARKERS = {
    "want",
    "looking",
    "searching",
    "need",
    "love",
    "like",
    "prefer",
    "enjoy",
    "recommend",
    "suggest",
    "vreau",
    "caut",
    "iubesc",
    "imi",
    "place",
    "plac",
    "prefer",
    "recomanzi",
    "recomanda",
    "sugerezi",
}

BOOK_CONTENT_MARKERS = {
    "fantasy",
    "fantastic",
    "fantastice",
    "fantastica",
    "magic",
    "magical",
    "magie",
    "sci fi",
    "science fiction",
    "sf",
    "dystopian",
    "distopic",
    "distopica",
    "war",
    "razboi",
    "friendship",
    "prietenie",
    "adventure",
    "aventura",
    "romance",
    "dragoste",
    "mystery",
    "mistery",
    "mister",
    "classic",
    "clasica",
    "clasice",
    "freedom",
    "libertate",
    "survival",
    "supravietuire",
    "surveillance",
    "control social",
    "social control",
}

BOOK_CONTENT_ALIASES = {
    "mistery": "mystery", # :))) ( Personal mistake, idk if it's a common one. )
}

ROMANIAN_BOOK_PREFERENCE_PATTERNS = (
    r"^(?:mie\s+)?imi\s+place\s+(.+)$",
    r"^(?:mie\s+)?imi\s+plac\s+(.+)$",
    r"^iubesc\s+(.+)$",
    r"^ador\s+(.+)$",
    r"^prefer\s+(.+)$",
)

ENGLISH_BOOK_PREFERENCE_PATTERNS = (
    r"^i\s+like\s+(.+)$",
    r"^i\s+love\s+(.+)$",
    r"^i\s+enjoy\s+(.+)$",
    r"^i\s+prefer\s+(.+)$",
)


def _rewrite_inferred_book_preference(topic: str, language_code: str) -> str:
    # Turn loose preference fragments into cleaner retrieval queries.
    cleaned_topic = re.sub(r"\s+", " ", topic).strip(" .!?;,:-")
    if not cleaned_topic:
        return ""

    if language_code == "ro":
        if re.fullmatch(r"sf(?:-ul)?", cleaned_topic):
            return "Vreau o carte science fiction."

        match = re.match(r"^carti(?:le)?\s+cu\s+(.+)$", cleaned_topic)
        if match:
            return f"Vreau o carte cu {match.group(1).strip()}."

        match = re.match(r"^carti(?:le)?\s+despre\s+(.+)$", cleaned_topic)
        if match:
            return f"Vreau o carte despre {match.group(1).strip()}."

        match = re.match(r"^genul\s+(.+)$", cleaned_topic)
        if match:
            return f"Vreau o carte din genul {match.group(1).strip()}."

        return f"Vreau o carte despre {cleaned_topic}."

    if re.fullmatch(r"(?:sf|sci[- ]?fi|science fiction)", cleaned_topic):
        return "I want a science fiction book."

    match = re.match(r"^books?\s+with\s+(.+)$", cleaned_topic)
    if match:
        return f"I want a book with {match.group(1).strip()}."

    match = re.match(r"^books?\s+about\s+(.+)$", cleaned_topic)
    if match:
        return f"I want a book about {match.group(1).strip()}."

    match = re.match(r"^(?:the\s+)?genre\s+(.+)$", cleaned_topic)
    if match:
        return f"I want a book in the genre {match.group(1).strip()}."

    return f"I want a book about {cleaned_topic}."


def normalize_user_text(text: str) -> str:
    # Normalize user input by:
    # - unifying the Unicode representation
    # - collapsing repeated spaces
    # - trimming leading and trailing whitespace
    normalized = unicodedata.normalize("NFKC", text)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _normalize_for_filter(text: str) -> str:
    # Normalize text for robust comparisons by:
    # - removing diacritics
    # - converting punctuation to spaces
    # - collapsing repeated spaces
    normalized = unicodedata.normalize("NFKD", text.casefold())
    normalized = "".join(
        char for char in normalized if not unicodedata.combining(char)
    )
    normalized = re.sub(r"[_\W]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _load_terms_from_file(file_path: Path) -> list[str]:
    # Load blocked terms from one plain-text file.
    #
    # The file supports comments and blank lines.
    if not file_path.exists():
        return []

    with file_path.open("r", encoding="utf-8") as file_handle:
        terms = []
        for raw_line in file_handle:
            stripped_line = raw_line.strip()
            if not stripped_line or stripped_line.startswith("#"):
                continue

            normalized_term = _normalize_for_filter(stripped_line)
            if normalized_term:
                terms.append(normalized_term)

    return sorted(set(terms))


def load_blocked_terms_ro() -> list[str]:
    return _load_terms_from_file(BLOCKED_TERMS_RO_FILE)


def load_blocked_terms_en() -> list[str]:
    return _load_terms_from_file(BLOCKED_TERMS_EN_FILE)


def _find_matches_in_text(text: str, blocked_terms: list[str]) -> list[str]:
    # Return every blocked term that matches the normalized input text.
    if not blocked_terms:
        return []

    normalized_text = _normalize_for_filter(text)
    if not normalized_text:
        return []

    tokens = set(normalized_text.split())
    matched_terms: list[str] = []

    for term in blocked_terms:
        if " " in term:
            if re.search(rf"(^|\s){re.escape(term)}(\s|$)", normalized_text):
                matched_terms.append(term)
        elif term in tokens:
            matched_terms.append(term)

    return matched_terms


def _contains_phrase(normalized_text: str, phrase: str) -> bool:
    # Check for a whole-phrase match inside normalized text.
    return bool(re.search(rf"(^|\s){re.escape(phrase)}(\s|$)", normalized_text))


def normalize_book_query_aliases(text: str) -> str:
    # Fix common user typos or aliases before retrieval happens.
    normalized = normalize_user_text(text)
    if not normalized:
        return normalized

    for source, target in BOOK_CONTENT_ALIASES.items():
        normalized = re.sub(
            rf"\b{re.escape(source)}\b",
            target,
            normalized,
            flags=re.IGNORECASE,
        )

    return normalized


@lru_cache(maxsize=1)
def _get_catalog_scope_data() -> dict[str, set[str]]:
    # Cache normalized title and author terms extracted from the catalog.
    books = load_books(DATA_FILE)

    titles: set[str] = set()
    authors: set[str] = set()
    author_surnames: set[str] = set()

    for book in books:
        normalized_title = _normalize_for_filter(book.title)
        normalized_author = _normalize_for_filter(book.author)

        if normalized_title:
            titles.add(normalized_title)

        if normalized_author:
            authors.add(normalized_author)
            author_parts = normalized_author.split()
            if author_parts and len(author_parts[-1]) >= 4:
                author_surnames.add(author_parts[-1])

    return {
        "titles": titles,
        "authors": authors,
        "author_surnames": author_surnames,
    }


def is_book_related_query(text: str) -> bool:
    # Decide locally whether a question is about books, authors, recommendations,
    # or known titles from this application catalog.
    normalized_text = _normalize_for_filter(normalize_book_query_aliases(text))
    if not normalized_text:
        return False

    tokens = set(normalized_text.split())

    if tokens & BOOK_OBJECT_MARKERS:
        return True

    catalog_scope_data = _get_catalog_scope_data()

    if any(
        _contains_phrase(normalized_text, phrase)
        for phrase in catalog_scope_data["titles"] | catalog_scope_data["authors"]
    ):
        return True

    if tokens & catalog_scope_data["author_surnames"]:
        return True

    if tokens & RECOMMENDATION_INTENT_MARKERS:
        if any(_contains_phrase(normalized_text, marker) for marker in BOOK_CONTENT_MARKERS):
            return True

    return False


def infer_book_query_from_preference(text: str, language_code: str) -> str | None:
    # Rewrite fragments like `I love dragons` into explicit book requests.
    cleaned_text = normalize_user_text(text)
    if not cleaned_text:
        return None

    lowered_text = cleaned_text.casefold()
    languages_to_try = [language_code] + [
        fallback_language for fallback_language in ("ro", "en")
        if fallback_language != language_code
    ]

    for candidate_language in languages_to_try:
        patterns = (
            ROMANIAN_BOOK_PREFERENCE_PATTERNS
            if candidate_language == "ro"
            else ENGLISH_BOOK_PREFERENCE_PATTERNS
        )

        topic = ""
        for pattern in patterns:
            match = re.match(pattern, lowered_text)
            if match:
                topic = match.group(1).strip(" .!?;,:-")
                break

        if len(topic) < 2:
            continue

        rewritten_query = _rewrite_inferred_book_preference(topic, candidate_language)
        if rewritten_query:
            return rewritten_query

        if candidate_language == "ro":
            return f"Vreau o carte despre {topic}."

        return f"I want a book about {topic}."

    return None


def find_blocked_terms(text: str) -> list[str]:
    # Return the offensive terms detected in the input text.
    #
    # Detection happens fully locally using the Romanian and English term lists.
    if not ENABLE_INPUT_FILTER:
        return []

    blocked_terms = sorted(set(load_blocked_terms_ro()) | set(load_blocked_terms_en()))
    return sorted(set(_find_matches_in_text(text, blocked_terms)))


def validate_user_query(raw_text: str) -> GuardrailResult:
    # Validate whether the input may enter the application flow.
    #
    # This local block happens before retrieval and before any OpenAI request.
    cleaned = normalize_user_text(raw_text)

    if not cleaned:
        return GuardrailResult(
            is_allowed=False,
            cleaned_text="",
            reason="Mesajul este gol. Te rog sa scrii o intrebare despre carti.",
            matched_terms=[],
        )

    if len(cleaned) < 3:
        return GuardrailResult(
            is_allowed=False,
            cleaned_text=cleaned,
            reason="Mesajul este prea scurt. Te rog sa formulezi o intrebare mai clara.",
            matched_terms=[],
        )

    if len(cleaned) > MAX_USER_QUERY_CHARS:
        return GuardrailResult(
            is_allowed=False,
            cleaned_text=cleaned,
            reason=(
                f"Mesajul este prea lung. Limita curenta este "
                f"{MAX_USER_QUERY_CHARS} caractere."
            ),
            matched_terms=[],
        )

    matched_terms = find_blocked_terms(cleaned)

    if matched_terms:
        return GuardrailResult(
            is_allowed=False,
            cleaned_text=cleaned,
            reason=(
                "Iti pot recomanda carti cu placere, dar te rog sa reformulezi "
                "fara limbaj ofensator."
            ),
            matched_terms=matched_terms,
        )

    return GuardrailResult(
        is_allowed=True,
        cleaned_text=cleaned,
        reason=None,
        matched_terms=[],
    )
