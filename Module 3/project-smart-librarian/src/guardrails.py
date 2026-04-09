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
    "mistery": "mystery",
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


def normalize_user_text(text: str) -> str:
    """
    Normalizeaza textul:
    - unifica forma Unicode
    - reduce spatiile multiple
    - elimina spatii la inceput/final
    """
    normalized = unicodedata.normalize("NFKC", text)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _normalize_for_filter(text: str) -> str:
    """
    Normalizeaza textul pentru comparatii robuste:
    - elimina diacriticele
    - transforma punctuatia in spatii
    - unifica spatiile
    """
    normalized = unicodedata.normalize("NFKD", text.casefold())
    normalized = "".join(
        char for char in normalized if not unicodedata.combining(char)
    )
    normalized = re.sub(r"[_\W]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _load_terms_from_file(file_path: Path) -> list[str]:
    """
    Incarca termenii blocati exclusiv din fisierul text indicat.
    Fisierul accepta comentarii si linii goale.
    """
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
    return bool(re.search(rf"(^|\s){re.escape(phrase)}(\s|$)", normalized_text))


def normalize_book_query_aliases(text: str) -> str:
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
    """
    Verifica local daca intrebarea pare sa fie despre carti, autori,
    recomandari sau titluri din catalogul aplicatiei.
    """
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

        if candidate_language == "ro":
            return f"Vreau o carte despre {topic}."

        return f"I want a book about {topic}."

    return None


def find_blocked_terms(text: str) -> list[str]:
    """
    Intoarce termenii ofensatori gasiti in text.
    Detectia se face exclusiv local, pe baza celor doua fisiere txt:
    unul pentru romana si unul pentru engleza.
    """
    if not ENABLE_INPUT_FILTER:
        return []

    blocked_terms = sorted(set(load_blocked_terms_ro()) | set(load_blocked_terms_en()))
    return sorted(set(_find_matches_in_text(text, blocked_terms)))


def validate_user_query(raw_text: str) -> GuardrailResult:
    """
    Verifica daca inputul poate intra in flow-ul aplicatiei.
    IMPORTANT:
    Blocam local, inainte de retrieval si inainte de orice apel OpenAI.
    """
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
