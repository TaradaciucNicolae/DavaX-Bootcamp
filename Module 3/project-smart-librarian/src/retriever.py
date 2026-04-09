# Semantic retrieval helpers that query the local Chroma collection.

import re
import unicodedata
from typing import Any

from src.config import TOP_K
from src.embeddings import embed_query
from src.vector_store import get_or_create_books_collection

QUERY_STOPWORDS = {
    "a",
    "about",
    "ador",
    "an",
    "and",
    "ask",
    "book",
    "books",
    "carte",
    "carti",
    "cartile",
    "ce",
    "cu",
    "de",
    "despre",
    "din",
    "doresc",
    "genre",
    "genul",
    "i",
    "imi",
    "in",
    "like",
    "love",
    "o",
    "plac",
    "place",
    "prefer",
    "recommend",
    "recomanda",
    "recomanzi",
    "suggest",
    "the",
    "vreau",
    "want",
    "with",
}

QUERY_TERM_ALIASES: dict[str, set[str]] = {
    "razboi": {"war"},
    "war": {"razboi"},
    "sf": {"science fiction", "sci fi"},
    "science fiction": {"sf", "sci fi"},
    "sci fi": {"science fiction", "sf"},
    "libertate": {"freedom"},
    "freedom": {"libertate"},
    "prietenie": {"friendship"},
    "friendship": {"prietenie"},
    "aventura": {"adventure"},
    "adventure": {"aventura"},
    "dragoste": {"romance", "love"},
    "romance": {"dragoste", "love"},
    "supravietuire": {"survival"},
    "survival": {"supravietuire"},
    "control social": {"social control"},
    "social control": {"control social"},
    "mister": {"mystery"},
    "mystery": {"mister"},
}

FIELD_WEIGHTS = {
    "genres": 8,
    "themes": 6,
    "tone": 4,
    "title": 3,
    "author": 2,
    "short_summary": 1,
}


def _first_result_list(value: Any) -> list[Any]:
    # Chroma groups results by query.
    #
    # This project always sends one query at a time, so we read only the first group.
    if isinstance(value, list) and value:
        return value[0]

    return []


def _normalize_text(value: str) -> str:
    # Normalize query and metadata text so local reranking stays language-tolerant.
    normalized = unicodedata.normalize("NFKD", str(value).casefold())
    normalized = "".join(
        char for char in normalized if not unicodedata.combining(char)
    )
    normalized = re.sub(r"[_\W]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def _contains_phrase(text: str, phrase: str) -> bool:
    # Check whether a normalized metadata phrase appears as a whole phrase.
    return bool(re.search(rf"(^|\s){re.escape(phrase)}(\s|$)", text))


def _expand_query_terms(query: str) -> tuple[str, set[str]]:
    # Add canonical genre/theme aliases so short Romanian requests rerank better.
    normalized_query = _normalize_text(query)
    terms = {
        token for token in normalized_query.split()
        if token and token not in QUERY_STOPWORDS
    }

    expanded_terms = set(terms)

    for phrase, aliases in QUERY_TERM_ALIASES.items():
        if _contains_phrase(normalized_query, phrase):
            expanded_terms.add(phrase)
            expanded_terms.update(aliases)

    return normalized_query, expanded_terms


def _metadata_values(metadata: dict[str, Any], field_name: str) -> list[str]:
    # Read one metadata field as a flat list of strings.
    value = metadata.get(field_name, "")
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    if str(value).strip():
        return [str(value)]
    return []


def _score_field(
    query_text: str,
    query_terms: set[str],
    metadata: dict[str, Any],
    field_name: str,
) -> int:
    # Score how strongly a query overlaps one metadata field.
    field_weight = FIELD_WEIGHTS[field_name]
    score = 0

    for raw_value in _metadata_values(metadata, field_name):
        normalized_value = _normalize_text(raw_value)
        if not normalized_value:
            continue

        if normalized_value in query_terms or _contains_phrase(query_text, normalized_value):
            score += field_weight
            continue

        value_tokens = {
            token for token in normalized_value.split()
            if token and token not in QUERY_STOPWORDS
        }
        overlap_count = len(value_tokens & query_terms)
        if overlap_count:
            score += min(overlap_count, 2)

    return score


def _score_match(query: str, metadata: dict[str, Any]) -> int:
    # Combine exact genre/theme hits with lighter metadata overlap signals.
    query_text, query_terms = _expand_query_terms(query)
    score = 0

    for field_name in FIELD_WEIGHTS:
        score += _score_field(query_text, query_terms, metadata, field_name)

    return score


def _rerank_matches(query: str, matches: list[dict[str, Any]]) -> list[dict[str, Any]]:
    # Keep semantic retrieval, but boost exact metadata matches for genre/theme requests.
    ranked_matches: list[tuple[int, float, int, dict[str, Any]]] = []

    for index, match in enumerate(matches):
        metadata = match.get("metadata") or {}
        distance = float(match.get("distance") or 0.0)
        boost_score = _score_match(query, metadata)
        ranked_matches.append((boost_score, distance, index, match))

    ranked_matches.sort(key=lambda item: (-item[0], item[1], item[2]))
    return [match for _, _, _, match in ranked_matches]


def search_books(query: str, n_results: int | None = None) -> list[dict[str, Any]]:
    # Find semantically relevant books for the user's question.
    #
    # The function returns a simplified list of matches that is easy for the chatbot
    # and UI layers to consume.
    cleaned_query = query.strip()

    if not cleaned_query:
        raise ValueError("The query cannot be empty.")

    collection = get_or_create_books_collection()
    query_embedding = embed_query(cleaned_query)
    requested_results = n_results or TOP_K

    try:
        collection_size = int(collection.count())
    except Exception:
        collection_size = requested_results

    overfetch_count = max(requested_results * 4, 12)
    overfetch_count = max(requested_results, min(collection_size, overfetch_count))

    raw_results = collection.query(
        query_embeddings=[query_embedding],
        n_results=overfetch_count,
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

    return _rerank_matches(cleaned_query, matches)[:requested_results]
