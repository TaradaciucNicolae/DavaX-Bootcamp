# Tool registry and cache helpers for exact-title summary lookups.

from src.config import DATA_FILE
from src.data_loader import BookSummary, get_book_by_exact_title, load_books

_BOOKS_CACHE: list[BookSummary] | None = None


def get_books_cache() -> list[BookSummary]:
    # Reuse the in-memory catalog so repeated tool calls stay fast.
    global _BOOKS_CACHE

    if _BOOKS_CACHE is None:
        _BOOKS_CACHE = load_books(DATA_FILE)

    return _BOOKS_CACHE


def set_books_cache(books: list[BookSummary] | None) -> None:
    # Update the cached catalog after imports or tests.
    global _BOOKS_CACHE
    _BOOKS_CACHE = books


def reload_books_cache() -> list[BookSummary]:
    # Reload the JSON catalog from disk and refresh the in-memory cache.
    books = load_books(DATA_FILE)
    set_books_cache(books)
    return books


def _clean_requested_title(title: str) -> str:
    # Remove surrounding quotes and whitespace from the model-provided title.
    return title.strip().strip('"').strip("'")


def get_summary_by_title(title: str) -> str:
    # Return the full summary for an exact catalog title.
    cleaned_title = _clean_requested_title(title)

    if not cleaned_title:
        return "Eroare: titlul primit este gol."

    books = get_books_cache()
    book = get_book_by_exact_title(cleaned_title, books)

    if book is None:
        books = reload_books_cache()
        book = get_book_by_exact_title(cleaned_title, books)

    if book is None:
        return f'Nu am gasit in baza locala o carte cu titlul "{cleaned_title}".'

    return book.full_summary


GET_SUMMARY_BY_TITLE_TOOL = {
    "type": "function",
    "name": "get_summary_by_title",
    "description": (
        "Return the full summary for a book that has already been selected from the catalog. "
        "Call this tool only after deciding the exact recommended title."
    ),
    "strict": True,
    "parameters": {
        "type": "object",
        "properties": {
            "title": {
                "type": "string",
                "description": "The exact recommended title, exactly as it appears in the catalog."
            }
        },
        "required": ["title"],
        "additionalProperties": False
    }
}


def execute_tool_call(tool_name: str, arguments: dict) -> str:
    # Dispatch a tool call to the concrete local implementation.
    if tool_name == "get_summary_by_title":
        title = arguments.get("title", "")
        return get_summary_by_title(title)

    raise ValueError(f"Unknown tool: {tool_name}")

