# Utility entry point that rebuilds the Chroma index from the local catalog.
#
# Typical uses:
# - initial setup
# - a reset after JSON catalog changes
# - a reset after embedding or metadata changes

from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.config import DATA_FILE
from src.data_loader import load_books
from src.vector_store import rebuild_vector_store


def main() -> None:
    # Load the validated catalog and rebuild the persistent Chroma collection.
    books = load_books(DATA_FILE)
    total = rebuild_vector_store(books)
    print(f"Index reconstruit. Carti indexate: {total}")


if __name__ == "__main__":
    main()

