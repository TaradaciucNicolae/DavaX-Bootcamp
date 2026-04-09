# Persistent Chroma collection management for the local book catalog.

from typing import Any

import chromadb

from src.config import CHROMA_PATH, COLLECTION_NAME
from src.data_loader import BookSummary
from src.embeddings import embed_texts


def get_chroma_client():
    # Create the persistent Chroma client stored on disk.
    CHROMA_PATH.mkdir(parents=True, exist_ok=True)
    return chromadb.PersistentClient(path=str(CHROMA_PATH))


def get_or_create_books_collection():
    # Return the catalog collection, creating it if needed.
    client = get_chroma_client()
    return client.get_or_create_collection(name=COLLECTION_NAME)


def delete_books_collection_if_exists() -> None:
    # Delete the current collection if it already exists.
    #
    # Full rebuilds start from a clean slate so stale vectors do not survive imports
    # or schema changes.
    client = get_chroma_client()

    try:
        client.delete_collection(name=COLLECTION_NAME)
    except Exception:
        # It is safe to ignore the error when the collection does not exist yet.
        pass


def _book_to_metadata(book: BookSummary) -> dict[str, Any]:
    # Extract the metadata fields that should stay queryable in Chroma.
    return {
        "title": book.title,
        "author": book.author,
        "audience": book.audience,
        "language": book.language,
        "genres": book.genres,
        "themes": book.themes,
        "tone": book.tone,
        "short_summary": book.short_summary,
    }


def rebuild_vector_store(books: list[BookSummary]) -> int:
    # Rebuild the entire vector store from the validated catalog.
    #
    # Steps:
    # 1. Delete the previous collection
    # 2. Create a fresh collection
    # 3. Generate embeddings for each book
    # 4. Upsert the full dataset into Chroma
    #
    # The return value is the total number of indexed records.
    delete_books_collection_if_exists()
    collection = get_or_create_books_collection()

    ids = [book.id for book in books]
    documents = [book.content_for_embedding for book in books]
    metadatas = [_book_to_metadata(book) for book in books]

    embeddings = embed_texts(documents)

    collection.upsert(
        ids=ids,
        documents=documents,
        metadatas=metadatas,
        embeddings=embeddings,
    )

    return collection.count()


def get_collection_size() -> int:
    # Return the current number of records stored in the collection.
    collection = get_or_create_books_collection()
    return collection.count()

