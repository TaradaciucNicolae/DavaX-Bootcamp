"""
rebuild_index.py

Reconstruieste indexul Chroma din datele locale.
Script util pentru:
- setup initial
- reset dupa schimbari in JSON
- reset dupa schimbari de embeddings / metadata
"""

from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.config import DATA_FILE
from src.data_loader import load_books
from src.vector_store import rebuild_vector_store


def main() -> None:
    books = load_books(DATA_FILE)
    total = rebuild_vector_store(books)
    print(f"Index reconstruit. Carti indexate: {total}")


if __name__ == "__main__":
    main()
