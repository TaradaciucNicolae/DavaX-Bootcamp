from typing import Any

from src.config import TOP_K
from src.embeddings import embed_query
from src.vector_store import get_or_create_books_collection


def _first_result_list(value: Any) -> list[Any]:
    """
    Chroma returneaza rezultatele grupate pe query.
    Noi trimitem un singur query, deci luam primul grup.
    """
    if isinstance(value, list) and value:
        return value[0]

    return []


def search_books(query: str, n_results: int | None = None) -> list[dict[str, Any]]:
    """
    Cauta semantic carti relevante pentru intrebarea utilizatorului.
    Returneaza o lista de rezultate simplificate.
    """
    cleaned_query = query.strip()

    if not cleaned_query:
        raise ValueError("Intrebarea nu poate fi goala.")

    collection = get_or_create_books_collection()
    query_embedding = embed_query(cleaned_query)

    raw_results = collection.query(
        query_embeddings=[query_embedding],
        n_results=n_results or TOP_K,
        include=["documents", "metadatas", "distances"],
    )

    ids = _first_result_list(raw_results.get("ids"))
    documents = _first_result_list(raw_results.get("documents"))
    metadatas = _first_result_list(raw_results.get("metadatas"))
    distances = _first_result_list(raw_results.get("distances"))

    matches: list[dict[str, Any]] = []

    for book_id, document, metadata, distance in zip(ids, documents, metadatas, distances):
        matches.append(
            {
                "id": book_id,
                "document": document,
                "metadata": metadata,
                "distance": distance,
            }
        )

    return matches