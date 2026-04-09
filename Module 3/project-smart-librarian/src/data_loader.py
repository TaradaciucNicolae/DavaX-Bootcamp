import json
from pathlib import Path
import re
from typing import Optional

from pydantic import BaseModel, Field, ValidationError


class BookSummary(BaseModel):
    id: str
    title: str
    author: str
    genres: list[str] = Field(min_length=1)
    themes: list[str] = Field(min_length=1)
    tone: list[str] = Field(min_length=1)
    audience: str
    language: str
    short_summary: str
    full_summary: str
    content_for_embedding: str


def load_books(file_path: Path) -> list[BookSummary]:
    """
    Citeste fisierul JSON si valideaza fiecare carte.
    Returneaza o lista de obiecte BookSummary.
    """
    if not file_path.exists():
        raise FileNotFoundError(f"Fisierul nu exista: {file_path}")

    with file_path.open("r", encoding="utf-8") as f:
        raw_data = json.load(f)

    if not isinstance(raw_data, list):
        raise ValueError("Fisierul JSON trebuie sa contina o lista de carti.")

    books: list[BookSummary] = []
    errors: list[str] = []

    for index, item in enumerate(raw_data):
        try:
            book = BookSummary.model_validate(item)
            books.append(book)
        except ValidationError as exc:
            errors.append(f"Eroare la elementul {index}: {exc}")

    if errors:
        raise ValueError(
            "Au fost gasite erori de validare in book_summaries.json:\n"
            + "\n".join(errors)
        )

    if len(books) < 10:
        raise ValueError(
            f"Trebuie sa ai minim 10 carti conform cerintei. Acum ai {len(books)}."
        )

    return books


def get_book_by_exact_title(title: str, books: list[BookSummary]) -> Optional[BookSummary]:
    """
    Cauta o carte dupa titlu exact, ignorand diferente minore de litere mari/mici.
    """
    resolved_title = resolve_catalog_title(title, [book.title for book in books])
    if not resolved_title:
        return None

    for book in books:
        if book.title.strip().casefold() == resolved_title.casefold():
            return book

    return None


def _normalize_title_key(title: str) -> str:
    cleaned_title = title.strip()
    cleaned_title = re.sub(r"^[`*_#\s]+|[`*_#\s]+$", "", cleaned_title)
    cleaned_title = cleaned_title.strip("\"'`“”„«»’‘")
    cleaned_title = re.sub(r"\s+", " ", cleaned_title)
    cleaned_title = re.sub(r"[.!?,;:]+$", "", cleaned_title)
    return cleaned_title.strip().casefold()


def _strip_author_suffix(title: str) -> str:
    stripped = re.sub(r"\s+\b(?:by|de)\b\s+.+$", "", title, flags=re.IGNORECASE)
    return stripped.strip()


def _build_title_aliases(title: str) -> set[str]:
    title_variants = {title.strip()}
    stripped_author = _strip_author_suffix(title)
    if stripped_author:
        title_variants.add(stripped_author)

    aliases: set[str] = set()
    separators = (":", " - ", " – ", " — ", "(")

    for variant in title_variants:
        normalized_variant = _normalize_title_key(variant)
        if normalized_variant:
            aliases.add(normalized_variant)

        for separator in separators:
            if separator not in variant:
                continue

            prefix = variant.split(separator, 1)[0].strip()
            normalized_prefix = _normalize_title_key(prefix)
            if normalized_prefix:
                aliases.add(normalized_prefix)

    return aliases


def resolve_catalog_title(title: str, catalog_titles: list[str]) -> Optional[str]:
    normalized_requested_title = _normalize_title_key(_strip_author_suffix(title))
    if not normalized_requested_title:
        return None

    unique_aliases: dict[str, str] = {}
    ambiguous_aliases: set[str] = set()

    for catalog_title in catalog_titles:
        for alias in _build_title_aliases(catalog_title):
            previous_title = unique_aliases.get(alias)
            if previous_title is None:
                unique_aliases[alias] = catalog_title
                continue

            if previous_title != catalog_title:
                ambiguous_aliases.add(alias)

    for ambiguous_alias in ambiguous_aliases:
        unique_aliases.pop(ambiguous_alias, None)

    return unique_aliases.get(normalized_requested_title)
