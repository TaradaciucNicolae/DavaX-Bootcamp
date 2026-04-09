from src.data_loader import BookSummary
from src.tools import get_summary_by_title


def _book(title: str, full_summary: str) -> BookSummary:
    return BookSummary(
        id=f"book_{title.lower().replace(' ', '_')}",
        title=title,
        author="Test Author",
        genres=["fiction"],
        themes=["identity"],
        tone=["serious"],
        audience="adult",
        language="en",
        short_summary=f"Short summary for {title}.",
        full_summary=full_summary,
        content_for_embedding=f"Title: {title}. Summary: {full_summary}",
    )


def test_get_summary_by_title_reloads_cache_when_book_was_imported_later(monkeypatch):
    stale_books = [_book("1984", "Old summary.")]
    fresh_books = [
        stale_books[0],
        _book("Newly Imported Book", "Fresh summary from the updated catalog."),
    ]

    monkeypatch.setattr("src.tools._BOOKS_CACHE", stale_books)
    monkeypatch.setattr("src.tools.load_books", lambda _: fresh_books)

    summary = get_summary_by_title("Newly Imported Book")

    assert summary == "Fresh summary from the updated catalog."
    assert get_summary_by_title("1984") == "Old summary."

