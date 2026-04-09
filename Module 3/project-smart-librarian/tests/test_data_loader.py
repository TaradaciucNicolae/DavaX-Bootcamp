# Tests for loading the local catalog and exact-title resolution.

from src.config import DATA_FILE
from src.data_loader import get_book_by_exact_title, load_books


def test_load_books_returns_minimum_ten_books():
    books = load_books(DATA_FILE)
    assert len(books) >= 10


def test_get_book_by_exact_title_finds_1984():
    books = load_books(DATA_FILE)
    book = get_book_by_exact_title("1984", books)

    assert book is not None
    assert book.title == "1984"
    assert "freedom" in [theme.casefold() for theme in book.themes]

