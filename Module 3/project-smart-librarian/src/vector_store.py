from typing import Any

import chromadb

from src.config import CHROMA_PATH, COLLECTION_NAME
from src.data_loader import BookSummary
from src.embeddings import embed_texts


def get_chroma_client():
    """
    Creeaza clientul Chroma persistent pe disk.
    """
    CHROMA_PATH.mkdir(parents=True, exist_ok=True)
    return chromadb.PersistentClient(path=str(CHROMA_PATH))


def get_or_create_books_collection():
    """
    Obtine colectia de carti daca exista sau o creeaza daca nu exista.
    """
    client = get_chroma_client()
    return client.get_or_create_collection(name=COLLECTION_NAME)


def delete_books_collection_if_exists() -> None:
    """
    Sterge colectia curenta daca exista deja.
    Folosim asta la rebuild complet, ca sa evitam date vechi sau inconsistente.
    """
    client = get_chroma_client()

    try:
        client.delete_collection(name=COLLECTION_NAME)
    except Exception:
        # Daca nu exista colectia, ignoram eroarea.
        pass


def _book_to_metadata(book: BookSummary) -> dict[str, Any]:
    """
    Extrage metadata utila pentru fiecare carte.
    """
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
    """
    Reconstruieste complet vector store-ul:
    1. Sterge colectia veche
    2. Creeaza colectia noua
    3. Genereaza embeddings pentru carti
    4. Salveaza datele in Chroma
    Returneaza numarul total de inregistrari din colectie.
    """
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
    """
    Returneaza cate inregistrari exista in colectie.
    """
    collection = get_or_create_books_collection()
    return collection.count()