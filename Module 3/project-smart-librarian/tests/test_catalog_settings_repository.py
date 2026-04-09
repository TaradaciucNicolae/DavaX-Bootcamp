import sqlite3
from pathlib import Path

from src.catalog_settings_repository import (
    CatalogImportSettings,
    init_settings_table,
    load_catalog_settings,
    save_catalog_settings,
)

TEST_DB_PATH = Path("tests") / "catalog_settings_test.db"


def _prepare_test_db(monkeypatch) -> Path:
    if TEST_DB_PATH.exists():
        try:
            TEST_DB_PATH.unlink()
        except PermissionError:
            with sqlite3.connect(TEST_DB_PATH) as conn:
                conn.execute("DROP TABLE IF EXISTS catalog_settings")
                conn.commit()

    monkeypatch.setattr("src.catalog_settings_repository.SETTINGS_DB_PATH", TEST_DB_PATH)
    return TEST_DB_PATH


def _cleanup_test_db(db_path: Path) -> None:
    if db_path.exists():
        try:
            db_path.unlink()
        except PermissionError:
            pass


def test_save_catalog_settings_normalizes_language_label(monkeypatch):
    db_path = _prepare_test_db(monkeypatch)
    try:
        settings = CatalogImportSettings(
            selected_labels=["Romance"],
            books_per_genre=5,
            language_restrict="Engleza",
            max_pages_per_query=2,
        )

        save_catalog_settings(settings)

        assert settings.language_restrict == "en"

        with sqlite3.connect(db_path) as conn:
            stored_value = conn.execute(
                "SELECT language_restrict FROM catalog_settings WHERE id = 1"
            ).fetchone()[0]

        assert stored_value == "en"
    finally:
        _cleanup_test_db(db_path)


def test_load_catalog_settings_migrates_legacy_language_label(monkeypatch):
    db_path = _prepare_test_db(monkeypatch)
    try:
        init_settings_table()

        with sqlite3.connect(db_path) as conn:
            conn.execute(
                """
                INSERT INTO catalog_settings (
                    id,
                    selected_labels_json,
                    books_per_genre,
                    language_restrict,
                    max_pages_per_query,
                    updated_at
                )
                VALUES (1, '["Romance"]', 4, 'Orice limba', 2, '2026-04-09T00:00:00+00:00')
                """
            )
            conn.commit()

        settings = load_catalog_settings()

        assert settings.language_restrict == "any"

        with sqlite3.connect(db_path) as conn:
            stored_value = conn.execute(
                "SELECT language_restrict FROM catalog_settings WHERE id = 1"
            ).fetchone()[0]

        assert stored_value == "any"
    finally:
        _cleanup_test_db(db_path)
