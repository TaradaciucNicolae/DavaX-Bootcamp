# Catalog import orchestration used by the Streamlit admin sidebar.

from src.catalog_settings_repository import CatalogImportSettings
from src.config import DATA_FILE
from src.data_loader import load_books
from src.tools import set_books_cache
from src.vector_store import rebuild_vector_store
from scripts.database_loader_script import (
    collect_books_for_query,
    merge_books_into_json,
)


def import_books_from_settings(settings: CatalogImportSettings) -> dict:
    # Run the complete ingestion flow driven by the saved sidebar settings.
    
    # The JSON file remains the source of truth, while Chroma is rebuilt from that
    # validated JSON so the chatbot and the exact-title tool stay in sync.
    settings.validate()

    all_new_items = []

    for query in settings.build_queries():
        items = collect_books_for_query(
            query=query,
            target_count=settings.books_per_genre,
            max_pages_per_query=settings.max_pages_per_query,
            language_restrict=settings.language_restrict,
        )
        all_new_items.extend(items)

    # Keep only the best normalized version for each generated book id.
    best_by_id = {}
    for item in all_new_items:
        current = best_by_id.get(item["id"])
        if current is None or item["_quality_score"] > current["_quality_score"]:
            best_by_id[item["id"]] = item

    deduped_items = list(best_by_id.values())

    # Merge into the local JSON catalog before re-validating the full dataset.
    final_json_items = merge_books_into_json(deduped_items, str(DATA_FILE))

    # Refresh both the tool cache and the semantic index used by chat_once().
    validated_books = load_books(DATA_FILE)
    set_books_cache(validated_books)
    indexed_total = rebuild_vector_store(validated_books)

    return {
        "new_items_in_this_run": len(deduped_items),
        "total_items_in_json": len(final_json_items),
        "indexed_total": indexed_total,
    }

