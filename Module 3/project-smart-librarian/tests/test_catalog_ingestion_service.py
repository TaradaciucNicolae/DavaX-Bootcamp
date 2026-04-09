# Tests for the end-to-end catalog import orchestration service.

import sys
from types import SimpleNamespace

sys.modules.setdefault(
    "chromadb",
    SimpleNamespace(PersistentClient=lambda *args, **kwargs: None),
)

from src.catalog_ingestion_service import import_books_from_settings
from src.catalog_settings_repository import CatalogImportSettings
from src.data_loader import BookSummary


def _book(title: str) -> BookSummary:
    # Build a minimal valid BookSummary used by the ingestion tests.
    return BookSummary(
        id=f"book_{title.lower().replace(' ', '_')}",
        title=title,
        author="Imported Author",
        genres=["fiction"],
        themes=["growth"],
        tone=["warm"],
        audience="adult",
        language="en",
        short_summary=f"Short summary for {title}.",
        full_summary=f"Full summary for {title}.",
        content_for_embedding=f"Title: {title}.",
    )


def test_import_books_from_settings_refreshes_tool_cache(monkeypatch):
    imported_items = [
        {
            "id": "book_new",
            "_quality_score": 9.5,
            "title": "New Imported Book",
        }
    ]
    validated_books = [_book("New Imported Book")]
    captured = {}

    monkeypatch.setattr(
        "src.catalog_ingestion_service.collect_books_for_query",
        lambda **kwargs: imported_items,
    )
    monkeypatch.setattr(
        "src.catalog_ingestion_service.merge_books_into_json",
        lambda items, path: items,
    )
    monkeypatch.setattr(
        "src.catalog_ingestion_service.load_books",
        lambda path: validated_books,
    )
    monkeypatch.setattr(
        "src.catalog_ingestion_service.set_books_cache",
        lambda books: captured.setdefault("books", books),
    )
    monkeypatch.setattr(
        "src.catalog_ingestion_service.rebuild_vector_store",
        lambda books: len(books),
    )

    settings = CatalogImportSettings(
        selected_labels=["Romance"],
        books_per_genre=1,
        language_restrict="en",
        max_pages_per_query=1,
    )

    result = import_books_from_settings(settings)

    assert captured["books"] == validated_books
    assert result["new_items_in_this_run"] == 1
    assert result["total_items_in_json"] == 1
    assert result["indexed_total"] == 1

