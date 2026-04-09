from src.config import DATA_FILE
from src.data_loader import BookSummary, get_book_by_exact_title, load_books

_BOOKS_CACHE: list[BookSummary] | None = None


def get_books_cache() -> list[BookSummary]:
    global _BOOKS_CACHE

    if _BOOKS_CACHE is None:
        _BOOKS_CACHE = load_books(DATA_FILE)

    return _BOOKS_CACHE


def set_books_cache(books: list[BookSummary] | None) -> None:
    global _BOOKS_CACHE
    _BOOKS_CACHE = books


def reload_books_cache() -> list[BookSummary]:
    books = load_books(DATA_FILE)
    set_books_cache(books)
    return books


def _clean_requested_title(title: str) -> str:
    """
    Curata titlul primit de la model.
    """
    return title.strip().strip('"').strip("'")


def get_summary_by_title(title: str) -> str:
    """
    Returneaza rezumatul complet pentru un titlu valid.
    """
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
        "Returneaza rezumatul complet pentru o carte deja aleasa din catalog. "
        "Apeleaza acest tool doar dupa ce ai decis titlul exact al cartii recomandate."
    ),
    "strict": True,
    "parameters": {
        "type": "object",
        "properties": {
            "title": {
                "type": "string",
                "description": "Titlul exact al cartii recomandate, asa cum apare in catalog."
            }
        },
        "required": ["title"],
        "additionalProperties": False
    }
}


def execute_tool_call(tool_name: str, arguments: dict) -> str:
    if tool_name == "get_summary_by_title":
        title = arguments.get("title", "")
        return get_summary_by_title(title)

    raise ValueError(f"Tool necunoscut: {tool_name}")
