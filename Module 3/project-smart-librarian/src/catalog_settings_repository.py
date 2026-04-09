import json
import sqlite3
from dataclasses import dataclass, field
from datetime import datetime, UTC

from src.config import BASE_DIR

SETTINGS_DB_PATH = BASE_DIR / "data" / "app_state.db"

# În UI afișezi etichete prietenoase.
# În spate le mapezi la query-urile reale pentru Google Books.
GENRE_QUERY_MAP = {
    "Ficțiune": "subject:fiction",
    "Romance": "subject:romance",
    "Fantasy": "subject:fantasy",
    "Mister": "subject:mystery",
    "Război": "subject:war",
    "Aventură": "subject:adventure",
    "SF": "subject:science fiction",
    "Crime": "subject:crime",
}

ALLOWED_LANGUAGES = {"en", "ro", "any"}
LANGUAGE_LABELS_BY_CODE = {
    "en": "Engleza",
    "ro": "Romana",
    "any": "Orice limba",
}
LANGUAGE_CODE_BY_LABEL = {
    label.casefold(): code for code, label in LANGUAGE_LABELS_BY_CODE.items()
}


def normalize_language_restrict(value: str) -> str:
    cleaned_value = str(value).strip()
    if cleaned_value in ALLOWED_LANGUAGES:
        return cleaned_value

    return LANGUAGE_CODE_BY_LABEL.get(cleaned_value.casefold(), cleaned_value)


@dataclass
class CatalogImportSettings:
    # Valorile default sunt folosite la prima rulare.
    selected_labels: list[str] = field(default_factory=lambda: ["Ficțiune", "Romance"])
    books_per_genre: int = 20
    language_restrict: str = "en"
    max_pages_per_query: int = 3

    def validate(self) -> None:
        self.language_restrict = normalize_language_restrict(self.language_restrict)
        # Validare strictă - foarte importantă pentru securitate și stabilitate.
        if not self.selected_labels:
            raise ValueError("Trebuie să alegi cel puțin un gen.")

        invalid = [label for label in self.selected_labels if label not in GENRE_QUERY_MAP]
        if invalid:
            raise ValueError(f"Genuri invalide: {invalid}")

        if not 1 <= self.books_per_genre <= 40:
            raise ValueError("books_per_genre trebuie să fie între 1 și 40.")

        if not 1 <= self.max_pages_per_query <= 10:
            raise ValueError("max_pages_per_query trebuie să fie între 1 și 10.")

        if self.language_restrict not in ALLOWED_LANGUAGES:
            raise ValueError("language_restrict invalid.")

    def build_queries(self) -> list[str]:
        # Transformă selecția din UI în query-uri reale pentru Google Books.
        return [GENRE_QUERY_MAP[label] for label in self.selected_labels]


def get_connection() -> sqlite3.Connection:
    SETTINGS_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(SETTINGS_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_settings_table() -> None:
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS catalog_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                selected_labels_json TEXT NOT NULL,
                books_per_genre INTEGER NOT NULL,
                language_restrict TEXT NOT NULL,
                max_pages_per_query INTEGER NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.commit()


def load_catalog_settings() -> CatalogImportSettings:
    init_settings_table()

    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM catalog_settings WHERE id = 1"
        ).fetchone()

    if row is None:
        settings = CatalogImportSettings()
        save_catalog_settings(settings)
        return settings

    settings = CatalogImportSettings(
        selected_labels=json.loads(row["selected_labels_json"]),
        books_per_genre=row["books_per_genre"],
        language_restrict=row["language_restrict"],
        max_pages_per_query=row["max_pages_per_query"],
    )
    settings.validate()

    if row["language_restrict"] != settings.language_restrict:
        save_catalog_settings(settings)

    return settings


def save_catalog_settings(settings: CatalogImportSettings) -> None:
    init_settings_table()
    settings.validate()

    with get_connection() as conn:
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
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                selected_labels_json = excluded.selected_labels_json,
                books_per_genre = excluded.books_per_genre,
                language_restrict = excluded.language_restrict,
                max_pages_per_query = excluded.max_pages_per_query,
                updated_at = excluded.updated_at
            """,
            (
                1,
                json.dumps(settings.selected_labels, ensure_ascii=False),
                settings.books_per_genre,
                settings.language_restrict,
                settings.max_pages_per_query,
                datetime.now(UTC).isoformat(),
            ),
        )
        conn.commit()
