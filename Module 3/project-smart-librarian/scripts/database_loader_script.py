# Normalize Google Books results into the JSON schema used by Smart Librarian.
#
# What does this script do ?
# - fetch books from Google Books
# - normalize inconsistent public metadata into one stable schema
# - build better short and full summaries using lightweight heuristics
# - merge new data into the local JSON catalog without losing existing entries
# - rebuild the semantic index used by the application
#
# Important note:
# Public book APIs do not expose clean fields such as themes, tone, audience,
# short_summary, or full_summary. Those fields are inferred from the available
# description, categories, and query context

from __future__ import annotations

import os
import random
import html
import json
import re
import time
import unicodedata
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests

from src.config import COLLECTION_NAME, DATA_FILE
from src.data_loader import load_books
from src.vector_store import rebuild_vector_store


# CONFIGURATION - MANUAL-RUN DEFAULTS ONLY

# These defaults are used only when this file is executed directly with:
# `python scripts/database_loader_script.py`
#
# They are not the values used by the Streamlit import flow.
# In the Streamlit UI, the selected genres, book count, language, and page
# limit are passed explicitly from the sidebar settings through
# `src.catalog_ingestion_service.py`.
#
# These constants exist only as fallback defaults for standalone/manual runs.
# When the application imports books from Streamlit, they are ignored.


# These are the seed queries sent to Google Books for standalone execution.
GOOGLE_BOOKS_QUERIES = [
    "subject:fiction",
    "subject:romance",
    "subject:fantasy",
]

# Standalone/manual-run target number of final books to keep per query.
TARGET_RESULTS_PER_QUERY = 20

# Standalone/manual-run limit for how many Google Books result pages to scan.
# Google Books allows at most 40 results per request, so the script pages
# through multiple result windows and then keeps the best candidates.
MAX_PAGES_PER_QUERY = 3

# Standalone/manual-run language restriction:
#   "en" -> English only
#   "ro" -> Romanian only
#   None -> any language
LANGUAGE_RESTRICT = "en"

# Output JSON file used by the standalone/manual execution path.
# The script merges by id instead of overwriting the file from scratch.
OUTPUT_JSON_PATH = "data/book_summaries.json"



# CONTROLLED VOCABULARY

# Google Books mostly exposes free-form `categories` and `description` data.
# These rules map recurring terms into a consistent internal vocabulary so the
# rest of the project can rely on stable genres, themes, and tone labels.

GENRE_RULES: List[Tuple[str, List[str]]] = [
    ("fantasy", ["fantasy", "magic", "magical realism"]),
    ("epic fantasy", ["epic fantasy"]),
    ("science fiction", ["science fiction", "sci-fi", "sf"]),
    ("dystopian", ["dystopian", "totalitarian", "post-apocalyptic"]),
    ("mystery", ["mystery", "detective", "whodunit"]),
    ("thriller", ["thriller", "suspense"]),
    ("romance", ["romance", "love story", "romantic"]),
    ("historical fiction", ["historical fiction", "historical"]),
    ("literary fiction", ["literary fiction", "literary"]),
    ("political fiction", ["political fiction", "political"]),
    ("social fiction", ["social fiction"]),
    ("war", ["war", "military", "wwi", "wwii", "world war"]),
    ("adventure", ["adventure", "quest", "journey"]),
    ("coming of age", ["coming of age", "bildungsroman"]),
    ("classic", ["classic", "classics"]),
    ("drama", ["drama"]),
    ("crime", ["crime", "criminal"]),
    ("horror", ["horror", "ghost", "supernatural horror"]),
    ("young adult", ["young adult", "ya", "teen"]),
    ("philosophical fiction", ["philosophical fiction", "philosophy"]),
    ("fable", ["fable"]),
    ("parable", ["parable"]),
]

THEME_RULES: List[Tuple[str, List[str]]] = [
    ("freedom", ["freedom", "liberty"]),
    ("social control", ["social control", "control", "oppression", "authoritarian", "totalitarian"]),
    ("surveillance", ["surveillance", "watched", "monitoring", "big brother"]),
    ("truth", ["truth", "lies", "propaganda", "history"]),
    ("resistance", ["resistance", "rebellion", "rebel", "defiance"]),
    ("friendship", ["friendship", "friends", "companion", "companionship"]),
    ("courage", ["courage", "bravery", "brave"]),
    ("journey", ["journey", "quest", "travel", "adventure"]),
    ("greed", ["greed", "treasure", "wealth", "gold"]),
    ("growth", ["growth", "maturity", "coming of age", "grows", "self-development"]),
    ("magic", ["magic", "wizard", "sorcery", "spell"]),
    ("identity", ["identity", "self", "self-discovery", "belonging"]),
    ("good versus evil", ["good versus evil", "dark forces", "evil", "light and dark"]),
    ("war", ["war", "battle", "conflict", "soldier"]),
    ("loss", ["loss", "grief", "mourning"]),
    ("survival", ["survival", "survive", "danger", "endurance"]),
    ("trauma", ["trauma", "psychological damage", "wounds", "shell shock"]),
    ("power", ["power", "authority", "rule", "empire"]),
    ("destiny", ["destiny", "fate", "prophecy"]),
    ("ecology", ["ecology", "environment", "nature"]),
    ("politics", ["politics", "political", "government"]),
    ("religion", ["religion", "faith", "messiah", "prophecy"]),
    ("justice", ["justice", "trial", "law", "fairness"]),
    ("empathy", ["empathy", "understanding", "compassion"]),
    ("racism", ["racism", "racial prejudice", "prejudice"]),
    ("childhood", ["childhood", "child", "growing up"]),
    ("moral courage", ["moral courage", "do what is right", "integrity"]),
    ("censorship", ["censorship", "banned books", "burn books"]),
    ("knowledge", ["knowledge", "learning", "books", "reading"]),
    ("conformity", ["conformity", "obedience", "uniformity"]),
    ("awakening", ["awakening", "begins to question", "realize", "awareness"]),
    ("language", ["language", "words", "storytelling", "writing"]),
    ("innocence", ["innocence", "naive", "childlike"]),
    ("meaning", ["meaning", "purpose", "what matters"]),
    ("imagination", ["imagination", "wonder", "dreamlike"]),
    ("love", ["love", "romance", "marriage"]),
    ("class", ["class", "social status", "rank"]),
    ("pride", ["pride", "ego", "vanity"]),
    ("misunderstanding", ["misunderstanding", "first impressions", "mistaken"]),
    ("talent", ["talent", "gifted", "genius", "music"]),
    ("ambition", ["ambition", "driven", "obsession", "success"]),
    ("books", ["books", "libraries", "reading", "authors", "writers"]),
    ("memory", ["memory", "memories", "past"]),
    ("secrets", ["secret", "secrets", "hidden"]),
    ("dreams", ["dream", "dreams", "vision"]),
    ("self-discovery", ["self-discovery", "find himself", "find herself"]),
    ("faith", ["faith", "belief", "spiritual"]),
    ("purpose", ["purpose", "calling", "meaning of life"]),
]

TONE_RULES: List[Tuple[str, List[str]]] = [
    ("dark", ["dark", "grim", "bleak"]),
    ("serious", ["serious", "grave"]),
    ("reflective", ["reflective", "philosophical", "introspective"]),
    ("warm", ["warm", "heartwarming", "tender"]),
    ("adventurous", ["adventure", "quest", "journey"]),
    ("hopeful", ["hope", "uplifting", "optimistic"]),
    ("magical", ["magic", "wizard", "enchanted"]),
    ("playful", ["playful", "fun", "whimsical"]),
    ("somber", ["somber", "sombre", "solemn"]),
    ("realistic", ["realistic", "realism"]),
    ("emotional", ["emotional", "moving", "heartbreaking"]),
    ("epic", ["epic", "large-scale", "saga"]),
    ("intense", ["intense", "high-stakes", "powerful"]),
    ("thoughtful", ["thoughtful", "thought-provoking"]),
    ("urgent", ["urgent", "immediate", "pressing"]),
    ("sad", ["sad", "tragic"]),
    ("human", ["human", "humane"]),
    ("poetic", ["poetic", "lyrical prose"]),
    ("gentle", ["gentle", "soft"]),
    ("witty", ["witty", "sharp humor", "ironic"]),
    ("elegant", ["elegant", "graceful"]),
    ("observant", ["observant", "social observation"]),
    ("lyrical", ["lyrical"]),
    ("mysterious", ["mysterious", "enigmatic"]),
    ("immersive", ["immersive", "rich worldbuilding"]),
    ("inspirational", ["inspirational", "encouraging"]),
    ("simple", ["simple", "plain style"]),
    ("atmospheric", ["atmospheric", "moody", "gothic"]),
    ("melancholic", ["melancholic", "melancholy"]),
]

PLOT_HINTS = [
    "follows", "story of", "tells the story", "centers on", "focuses on",
    "after", "when", "while", "must", "begins", "finds", "discovers",
    "joins", "faces", "drawn into", "set in", "forced to", "search for",
    "quest", "struggles", "journey", "learns", "survive", "questions",
]

PROMOTIONAL_NOISE_PATTERNS = [
    "new york times",
    "bestselling author",
    "bestseller",
    "publisher's description",
    "now a major motion picture",
    "soon to be a major motion picture",
    "special edition",
    "collector's edition",
    "includes bonus",
    "with an introduction by",
    "with a foreword by",
    "review",
    "praise for",
    "advance praise",
    "isbn",
    "paperback",
    "hardcover",
    "a novel by",
    "google books",
]

GENERIC_STOPWORDS = {
    "the", "a", "an", "and", "or", "of", "to", "in", "on", "with", "for",
    "by", "is", "are", "this", "that", "from", "at", "as", "it", "its",
    "into", "their", "his", "her", "about", "through", "during", "over",
}



# TEXT UTILITIES

def slugify(value: str) -> str:
    # Turn text into a simple slug used for generated identifiers.
    #
    # Example:
    # "The Shadow of the Wind" -> "the_shadow_of_the_wind"
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "_", value).strip("_")
    return value or "book"


def strip_html(value: str) -> str:
    # Strip light HTML markup returned by the API and normalize spacing.
    
    # Google Books may return:
    # - <br>
    # - <p>
    # - HTML entities
    
    # The output is plain text that is easier to score and summarize.
    value = html.unescape(value or "")
    value = value.replace("\u00a0", " ")
    value = re.sub(r"<br\s*/?>", ". ", value, flags=re.IGNORECASE)
    value = re.sub(r"</p\s*>", " ", value, flags=re.IGNORECASE)
    value = re.sub(r"<[^>]+>", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def normalize_punctuation(text: str) -> str:
    # Normalize quotes, dashes, and repeated spaces to avoid odd-looking summaries.
    text = (text or "").replace("“", '"').replace("”", '"').replace("’", "'").replace("–", "-")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def split_sentences(text: str) -> List[str]:
    # Split text into sentences.
    text = normalize_punctuation(text)
    if not text:
        return []
    parts = re.split(r"(?<=[.!?])\s+", text)
    return [p.strip() for p in parts if p.strip()]


def dedupe_preserve_order(values: List[str]) -> List[str]:
    # Remove duplicates while preserving the original order.
    out: List[str] = []
    seen = set()
    for value in values:
        key = value.strip().lower()
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(value.strip())
    return out


def normalize_title(info: Dict[str, Any]) -> str:
    # Build the final title from:
    # - title
    # - the optional subtitle when it is not already included
    title = strip_html(str(info.get("title", "")).strip())
    subtitle = strip_html(str(info.get("subtitle", "")).strip())

    if subtitle and subtitle.lower() not in title.lower():
        return f"{title}: {subtitle}"
    return title or "Unknown Title"


def normalize_author(info: Dict[str, Any]) -> str:
    # Take the first available author.
    #
    # This is enough for the current catalog schema and UI.
    authors = info.get("authors") or []
    if authors:
        return strip_html(str(authors[0]))
    return "Unknown"


def build_book_id(title: str, author: str) -> str:
    # Build the book identifier.
    #
    # Example:
    # "1984" -> "book_1984"
    #
    # Note:
    # - the current format intentionally stays simple and title-based
    # - if title collisions become common later, include the author slug too
    return f"book_{slugify(title)}"


def safe_take_unique(values: List[str], limit: int) -> List[str]:
    # Take the first unique non-empty values up to the requested limit.
    out: List[str] = []
    seen = set()
    for value in values:
        value = value.strip()
        if not value:
            continue
        key = value.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(value)
        if len(out) >= limit:
            break
    return out


def subject_from_query(query: str) -> str:
    # Extract the main subject from the source query.
    
    # Example:
    # "subject:romance" -> "romance"
    if "subject:" in query:
        return query.split("subject:", 1)[1].strip().strip('"').strip("'")
    return query.strip()


def keyword_match(text: str, keywords: List[str]) -> bool:
    # Perform a simple normalized keyword match.

    text = f" {text.lower()} "
    for keyword in keywords:
        if f" {keyword.lower()} " in text or keyword.lower() in text:
            return True
    return False



# SUMMARY-BUILDING HELPERS + CLEANUP ( precum ensure_description_text, sentence_score, build_short_summary, build_full_summary )

def ensure_description_text(description: str) -> str:
    # Clean the raw description and remove as much marketing noise as possible.
    description = strip_html(description)
    description = normalize_punctuation(description)

    if not description:
        return ""

    description = re.sub(r"\[(.*?)\]", " ", description)
    description = re.sub(r"\((?:unabridged|abridged|revised edition|updated edition)\)", " ", description, flags=re.IGNORECASE)
    description = re.sub(r"\s+", " ", description).strip()

    cleaned_sentences: List[str] = []
    for sentence in split_sentences(description):
        lower = sentence.lower()

        if len(sentence) < 25:
            continue

        if any(pattern in lower for pattern in PROMOTIONAL_NOISE_PATTERNS):
            continue

        if re.search(r"\b(?:isbn|ebook|paperback|hardcover)\b", lower):
            continue

        cleaned_sentences.append(sentence)

    cleaned_sentences = dedupe_preserve_order(cleaned_sentences)
    return " ".join(cleaned_sentences).strip()


def sentence_signature(sentence: str) -> str:
    # Build a tiny signature for near-duplicate sentence detection.
    tokens = re.findall(r"[a-zA-Z']+", sentence.lower())
    tokens = [t for t in tokens if t not in GENERIC_STOPWORDS]
    return " ".join(tokens[:12])


def sentence_score(sentence: str, index_in_description: int) -> int:
    # Score a sentence to decide whether it deserves a place in the summary.
    lower = sentence.lower()
    score = 0
    length = len(sentence)

    score += max(0, 6 - index_in_description)

    if 60 <= length <= 220:
        score += 6
    elif 35 <= length < 60 or 220 < length <= 320:
        score += 3
    else:
        score -= 2

    if any(hint in lower for hint in PLOT_HINTS):
        score += 8

    if any(word in lower for word in ["explores", "examines", "questions", "struggles", "rebels", "search", "truth", "power"]):
        score += 4

    if any(pattern in lower for pattern in PROMOTIONAL_NOISE_PATTERNS):
        score -= 10

    if sentence.endswith("?"):
        score -= 3

    if sentence.count("!") > 0:
        score -= 2

    if re.search(r"\b\d{4}\b", sentence) and length < 70:
        score -= 2

    return score


def choose_best_sentences(description: str, max_sentences: int, max_chars: int) -> List[str]:
    # Select the highest-value sentences for the generated summary.
    cleaned = ensure_description_text(description)
    sentences = split_sentences(cleaned)
    if not sentences:
        return []

    scored_rows = []
    for idx, sentence in enumerate(sentences):
        scored_rows.append({
            "index": idx,
            "sentence": sentence,
            "score": sentence_score(sentence, idx),
            "signature": sentence_signature(sentence),
        })

    ranked = sorted(scored_rows, key=lambda row: row["score"], reverse=True)

    selected_rows = []
    seen_signatures = set()
    current_length = 0

    for row in ranked:
        if row["signature"] in seen_signatures:
            continue

        sentence = row["sentence"]
        extra_len = len(sentence) + (1 if selected_rows else 0)
        if current_length + extra_len > max_chars:
            continue

        selected_rows.append(row)
        seen_signatures.add(row["signature"])
        current_length += extra_len

        if len(selected_rows) >= max_sentences:
            break

    if not selected_rows:
        current_length = 0
        for idx, sentence in enumerate(sentences):
            extra_len = len(sentence) + (1 if idx else 0)
            if current_length + extra_len > max_chars:
                break
            selected_rows.append({
                "index": idx,
                "sentence": sentence,
                "score": 0,
                "signature": sentence_signature(sentence),
            })
            current_length += extra_len
            if len(selected_rows) >= max_sentences:
                break

    selected_rows.sort(key=lambda row: row["index"])
    return [row["sentence"] for row in selected_rows]


def build_support_sentence(
    genres: List[str],
    themes: List[str],
    tone: List[str],
    audience: str,
    detailed: bool = False,
) -> str:
    # Build a fallback support sentence when the source description is too thin.
    #
    # detailed=False  -> short_summary fallback
    # detailed=True   -> full_summary fallback
    genre_text = ", ".join(genres[:3]) if genres else "fiction"
    theme_text = ", ".join(themes[:4]) if themes else "identity, growth"
    tone_text = ", ".join(tone[:3]) if tone else "engaging"

    if detailed:
        return (
            f"The book fits best in {genre_text}. "
            f"It especially explores {theme_text}. "
            f"The tone is {tone_text}, and it is best suited to {audience} readers."
        )

    return (
        f"It blends {genre_text}, explores {theme_text}, "
        f"and has a {tone_text} tone."
    )


def trim_to_sentence_boundary(text: str, max_chars: int) -> str:
    # Trim text to a character limit without leaving an ugly / broken sentence.
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) <= max_chars:
        return text

    truncated = text[:max_chars].rstrip()
    last_punct = max(truncated.rfind("."), truncated.rfind("!"), truncated.rfind("?"))

    if last_punct >= int(max_chars * 0.6):
        return truncated[: last_punct + 1].strip()

    last_space = truncated.rfind(" ")
    if last_space > 0:
        return truncated[:last_space].rstrip(" ,;:-") + "..."
    return truncated + "..."


def build_short_summary(
    title: str,
    author: str,
    description: str,
    genres: List[str],
    themes: List[str],
    tone: List[str],
    audience: str,
) -> str:
    # Build a more natural short summary from the available metadata.
    selected = choose_best_sentences(description, max_sentences=2, max_chars=300)
    candidate = " ".join(selected).strip()

    if candidate and len(candidate) < 110:
        candidate = f"{candidate} {build_support_sentence(genres, themes, tone, audience, detailed=False)}".strip()

    if candidate:
        return trim_to_sentence_boundary(candidate, 320)

    genre_text = ", ".join(genres[:2]) if genres else "fiction"
    theme_text = ", ".join(themes[:3]) if themes else "identity, growth"
    tone_text = ", ".join(tone[:2]) if tone else "engaging"
    return (
        f'"{title}" by {author} is a {genre_text} book for {audience} readers. '
        f'It explores {theme_text} in a {tone_text} style.'
    )


def build_full_summary(
    title: str,
    author: str,
    description: str,
    genres: List[str],
    themes: List[str],
    tone: List[str],
    audience: str,
) -> str:
    # Build a more coherent long summary from the available metadata.
    selected = choose_best_sentences(description, max_sentences=4, max_chars=760)
    full_summary = " ".join(selected).strip()

    if full_summary:
        if len(full_summary) < 260:
            full_summary = f"{full_summary} {build_support_sentence(genres, themes, tone, audience, detailed=True)}".strip()

        return trim_to_sentence_boundary(full_summary, 850)

    genre_text = ", ".join(genres[:3]) if genres else "fiction"
    theme_text = ", ".join(themes[:4]) if themes else "identity, growth"
    tone_text = ", ".join(tone[:3]) if tone else "engaging"
    return (
        f'"{title}" by {author} is a {genre_text} book aimed at {audience} readers. '
        f'Based on the available metadata, it focuses on {theme_text}. '
        f'The overall tone is {tone_text}. '
        f'This summary was generated from public book metadata.'
    )


def build_content_for_embedding(item: Dict[str, Any]) -> str:
    # Build the main text sent to Chroma for embeddings.
    
    # Chroma embeds the `documents` field, so this text combines structural fields
    # with the generated summaries to maximize semantic recall.
    return (
        f"Title: {item['title']}. "
        f"Author: {item['author']}. "
        f"Genres: {', '.join(item['genres'])}. "
        f"Themes: {', '.join(item['themes'])}. "
        f"Tone: {', '.join(item['tone'])}. "
        f"Audience: {item['audience']}. "
        f"Language: {item['language']}. "
        f"Short summary: {item['short_summary']} "
        f"Full summary: {item['full_summary']}"
    )



# GOOGLE BOOKS API

GOOGLE_BOOKS_VOLUMES_URL = "https://www.googleapis.com/books/v1/volumes"


GOOGLE_BOOKS_API_KEY = os.getenv(
    "GOOGLE_BOOKS_API_KEY",
)

RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}

def request_json(url: str, params: dict | None = None, timeout: int = 20, max_attempts: int = 5):
    # Fetch JSON with retries and optional Google Books API key injection.
    params = dict(params or {})
    last_error = None

    # Attach the Google Books API key only for Google Books requests.
    if (
        url == GOOGLE_BOOKS_VOLUMES_URL
        and GOOGLE_BOOKS_API_KEY
        and GOOGLE_BOOKS_API_KEY != "GOOGLE_BOOKS_API_KEY"
        and "key" not in params
    ):
        params["key"] = GOOGLE_BOOKS_API_KEY

    for attempt in range(max_attempts):
        try:
            response = requests.get(url, params=params, timeout=timeout)

            if response.status_code in RETRYABLE_STATUS_CODES:
                if attempt == max_attempts - 1:
                    response.raise_for_status()

                retry_after = response.headers.get("Retry-After")
                if retry_after and retry_after.isdigit():
                    sleep_seconds = int(retry_after)
                else:
                    sleep_seconds = min((2 ** attempt) + random.random(), 32)

                time.sleep(sleep_seconds)
                continue

            response.raise_for_status()
            return response.json()

        except requests.exceptions.Timeout as exc:
            last_error = exc

        except requests.exceptions.HTTPError as exc:
            last_error = exc
            status = exc.response.status_code if exc.response is not None else None
            if status not in RETRYABLE_STATUS_CODES or attempt == max_attempts - 1:
                raise

        except requests.exceptions.RequestException as exc:
            last_error = exc
            if attempt == max_attempts - 1:
                raise

        time.sleep(min((2 ** attempt) + random.random(), 32))

    raise last_error




def fetch_google_books_candidates(
    query: str,
    *,
    max_pages_per_query: int,
    language_restrict: str | None,
) -> List[Dict[str, Any]]:
    # Fetch raw Google Books candidates using the values provided by the UI settings.
    all_items: List[Dict[str, Any]] = []
    seen_volume_ids = set()

    for page_index in range(max_pages_per_query):
        start_index = page_index * 40

        params = {
            "q": query,
            "startIndex": start_index,
            "maxResults": 40,
            "projection": "full",
            "printType": "books",
            "orderBy": "relevance",
        }

        if language_restrict and language_restrict != "any":
            params["langRestrict"] = language_restrict

        data = request_json(GOOGLE_BOOKS_VOLUMES_URL, params=params)
        items = data.get("items", [])
        if not items:
            break

        for item in items:
            volume_id = item.get("id")
            if not volume_id or volume_id in seen_volume_ids:
                continue
            seen_volume_ids.add(volume_id)
            all_items.append(item)

    return all_items



# SEMANTIC EXTRACTION

def infer_genres(categories: List[str], description: str, query: str) -> List[str]:
    # Infer the main genres from categories, description, and query fallback.
    text = " | ".join(categories + [description, subject_from_query(query)]).lower()
    genres: List[str] = []

    for canonical, keywords in GENRE_RULES:
        if keyword_match(text, keywords):
            genres.append(canonical)

    if not genres:
        fallback = subject_from_query(query).lower()
        if fallback in {"fiction", "romance", "action", "fantasy", "mystery"}:
            genres.append(fallback)
        else:
            genres.append("fiction")

    return safe_take_unique(genres, 5)


def infer_themes(categories: List[str], description: str) -> List[str]:
    # Infer the main book themes from the description and categories.
    text = " | ".join(categories + [description]).lower()
    themes: List[str] = []

    for canonical, keywords in THEME_RULES:
        if keyword_match(text, keywords):
            themes.append(canonical)

    if not themes:
        generic = []
        if "romance" in text or "love" in text:
            generic.append("love")
        if "journey" in text or "adventure" in text:
            generic.append("journey")
        if "family" in text:
            generic.append("family")
        if not generic:
            generic = ["identity", "growth", "storytelling"]
        themes = generic

    return safe_take_unique(themes, 5)


def infer_tone(categories: List[str], description: str) -> List[str]:
    # Infer the dominant tone of the book.
    text = " | ".join(categories + [description]).lower()
    tones: List[str] = []

    for canonical, keywords in TONE_RULES:
        if keyword_match(text, keywords):
            tones.append(canonical)

    if not tones:
        if "romance" in text:
            tones = ["emotional", "warm"]
        elif "mystery" in text or "thriller" in text:
            tones = ["mysterious", "intense"]
        elif "fantasy" in text or "adventure" in text:
            tones = ["adventurous", "immersive"]
        else:
            tones = ["serious", "engaging"]

    return safe_take_unique(tones, 4)


def infer_audience(categories: List[str], description: str, maturity_rating: str) -> str:
    # Infer the target audience for the normalized schema.
    text = " | ".join(categories + [description, maturity_rating or ""]).lower()

    if any(term in text for term in ["children", "picture book", "juvenile", "kids"]):
        return "children"

    if "young adult" in text or re.search(r"\bya\b", text) or "teen" in text:
        return "young_adult"

    if any(term in text for term in ["all ages", "for all ages", "family read", "parable", "fable"]):
        return "all_ages"

    if any(term in text for term in ["coming of age", "classic", "fantasy adventure"]):
        return "teen_adult"

    if maturity_rating and maturity_rating.lower() == "mature":
        return "adult"

    return "adult"


def quality_score(info: Dict[str, Any], description: str, categories: List[str]) -> int:
    # Calculate a simple quality score used to rank normalized candidates.
    score = 0

    title = normalize_title(info)
    authors = info.get("authors") or []
    subtitle = strip_html(str(info.get("subtitle", "")))

    if title and title != "Unknown Title":
        score += 10
    if authors:
        score += 10
    if categories:
        score += 10
    if subtitle:
        score += 2

    desc_len = len(description)
    if desc_len >= 600:
        score += 35
    elif desc_len >= 350:
        score += 28
    elif desc_len >= 180:
        score += 18
    elif desc_len >= 100:
        score += 10
    elif desc_len > 0:
        score += 4

    ratings_count = int(info.get("ratingsCount", 0) or 0)
    avg_rating = float(info.get("averageRating", 0) or 0)

    if ratings_count >= 100:
        score += 10
    elif ratings_count >= 20:
        score += 6
    elif ratings_count > 0:
        score += 2

    if avg_rating >= 4.2:
        score += 5
    elif avg_rating >= 3.8:
        score += 3

    return score


def normalize_book(raw_item: Dict[str, Any], query: str) -> Dict[str, Any]:
    # Transform one raw Google Books item into the fixed project schema.
    #
    # Final schema:
    # {
    # id,
    # title,
    # author,
    # genres,
    # themes,
    # tone,
    # audience,
    # language,
    # short_summary,
    # full_summary,
    # content_for_embedding
    # }
    info = raw_item.get("volumeInfo", {})
    search_info = raw_item.get("searchInfo", {}) or {}

    title = normalize_title(info)
    author = normalize_author(info)

    categories = [strip_html(str(x)) for x in (info.get("categories") or []) if str(x).strip()]
    categories = safe_take_unique(categories, 8)

    description = strip_html(info.get("description") or search_info.get("textSnippet") or "")
    language = (info.get("language") or "unknown").strip().lower()
    maturity_rating = str(info.get("maturityRating") or "").strip()

    genres = infer_genres(categories, description, query)
    themes = infer_themes(categories, description)
    tone = infer_tone(categories, description)
    audience = infer_audience(categories, description, maturity_rating)

    item = {
        "id": build_book_id(title, author),
        "title": title,
        "author": author,
        "genres": genres,
        "themes": themes,
        "tone": tone,
        "audience": audience,
        "language": language or "unknown",
        "short_summary": build_short_summary(title, author, description, genres, themes, tone, audience),
        "full_summary": build_full_summary(title, author, description, genres, themes, tone, audience),
    }

    item["content_for_embedding"] = build_content_for_embedding(item)
    item["_quality_score"] = quality_score(info, description, categories)
    return item



# JSON MERGE

def ensure_parent_dir_for_file(file_path: str) -> None:
    # Create the parent directory for a file path if it does not exist yet.
    path = Path(file_path)
    if path.parent and str(path.parent) not in {"", "."}:
        path.parent.mkdir(parents=True, exist_ok=True)


def merge_books_into_json(new_items: List[Dict[str, Any]], output_path: str) -> List[Dict[str, Any]]:
    # Merge the current run into the existing JSON catalog.
    #
    # The book id is the primary key, so a newly normalized entry replaces the
    # older version with the same id.
    ensure_parent_dir_for_file(output_path)

    path = Path(output_path)
    existing_items: List[Dict[str, Any]] = []

    if path.exists():
        try:
            existing_items = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(existing_items, list):
                existing_items = []
        except Exception:
            existing_items = []

    merged: Dict[str, Dict[str, Any]] = {}

    for item in existing_items:
        if isinstance(item, dict) and item.get("id"):
            merged[item["id"]] = item

    for item in new_items:
        clean_item = {k: v for k, v in item.items() if not k.startswith("_")}
        merged[clean_item["id"]] = clean_item

    final_items = list(merged.values())
    final_items.sort(key=lambda x: x["title"].lower())

    path.write_text(json.dumps(final_items, ensure_ascii=False, indent=2), encoding="utf-8")
    return final_items


def collect_books_for_query(
    query: str,
    *,
    target_count: int,
    max_pages_per_query: int,
    language_restrict: str | None,
) -> List[Dict[str, Any]]:
    # Normalize, filter, deduplicate, and rank the best books for one query.
    raw_candidates = fetch_google_books_candidates(
        query=query,
        max_pages_per_query=max_pages_per_query,
        language_restrict=language_restrict,
    )

    normalized: List[Dict[str, Any]] = []
    seen_ids = set()

    for raw_item in raw_candidates:
        book = normalize_book(raw_item, query)

        if len(book["short_summary"]) < 90 or len(book["full_summary"]) < 170:
            continue

        if book["id"] in seen_ids:
            for idx, existing in enumerate(normalized):
                if existing["id"] == book["id"]:
                    if book["_quality_score"] > existing["_quality_score"]:
                        normalized[idx] = book
                    break
            continue

        seen_ids.add(book["id"])
        normalized.append(book)

    normalized.sort(key=lambda x: x["_quality_score"], reverse=True)
    return normalized[:target_count]


def main() -> None:
    # Run the standalone import flow from Google Books to JSON to Chroma.
    # This entry point uses only the manual-run defaults defined at the top of
    # the file. 
    # 
    # The Streamlit app does not call `main()` and does not rely on
    # `GOOGLE_BOOKS_QUERIES`, `TARGET_RESULTS_PER_QUERY`, `MAX_PAGES_PER_QUERY`,
    # or `LANGUAGE_RESTRICT` from this section.
    all_new_items: List[Dict[str, Any]] = []

    print("[1/4] Colectez carti din Google Books API")
    for query in GOOGLE_BOOKS_QUERIES:
        print(f"   - query: {query!r}")
        items = collect_books_for_query(
            query=query,
            target_count=TARGET_RESULTS_PER_QUERY,
            max_pages_per_query=MAX_PAGES_PER_QUERY,
            language_restrict=LANGUAGE_RESTRICT,
        )
        print(f"     -> rezultate selectate: {len(items)}")
        all_new_items.extend(items)

    best_by_id: Dict[str, Dict[str, Any]] = {}
    for item in all_new_items:
        current = best_by_id.get(item["id"])
        if current is None or item["_quality_score"] > current["_quality_score"]:
            best_by_id[item["id"]] = item

    deduped_items = list(best_by_id.values())
    deduped_items.sort(key=lambda x: (x["title"].lower(), x["author"].lower()))

    print(f"[2/4] Merge in JSON: {OUTPUT_JSON_PATH}")
    final_json_items = merge_books_into_json(deduped_items, OUTPUT_JSON_PATH)
    print(f"   -> total intrari in JSON dupa merge: {len(final_json_items)}")

    print("[3/4] Validez JSON-ul final și reconstruiesc indexul semantic al aplicației")
    validated_books = load_books(DATA_FILE)
    indexed_total = rebuild_vector_store(validated_books)
    print(f"   -> total cărți indexate: {indexed_total}")

    print("[4/4] Gata.")
    print(f"Carti noi procesate in aceasta rulare: {len(deduped_items)}")
    print(f"JSON final: {OUTPUT_JSON_PATH}")
    print(f"Colectie Chroma: {COLLECTION_NAME}")


if __name__ == "__main__":
    main()

