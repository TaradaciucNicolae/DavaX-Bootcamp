from pathlib import Path
import os

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_FILE = BASE_DIR / "data" / "book_summaries.json"
BLOCKED_TERMS_RO_FILE = BASE_DIR / "data" / "blocked_terms_ro.txt"
BLOCKED_TERMS_EN_FILE = BASE_DIR / "data" / "blocked_terms_en.txt"
LOG_DIR = BASE_DIR / "logs"

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4.1")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")
STT_MODEL = os.getenv("STT_MODEL", "gpt-4o-mini-transcribe")
STT_RESPONSE_FORMAT = os.getenv("STT_RESPONSE_FORMAT", "text")
TTS_MODEL = os.getenv("TTS_MODEL", "gpt-4o-mini-tts")
TTS_VOICE = os.getenv("TTS_VOICE", "alloy")
TTS_RESPONSE_FORMAT = os.getenv("TTS_RESPONSE_FORMAT", "mp3")
MODERATION_MODEL = os.getenv("MODERATION_MODEL", "omni-moderation-latest")
IMAGE_MODEL = os.getenv("IMAGE_MODEL", "gpt-image-1-mini")
IMAGE_OUTPUT_FORMAT = os.getenv("IMAGE_OUTPUT_FORMAT", "png")
IMAGE_QUALITY = os.getenv("IMAGE_QUALITY", "low")
IMAGE_STYLE = os.getenv("IMAGE_STYLE", "vivid")
IMAGE_COVER_SIZE = os.getenv("IMAGE_COVER_SIZE", "1024x1536")
IMAGE_SCENE_SIZE = os.getenv("IMAGE_SCENE_SIZE", "1536x1024")
CHROMA_PATH = Path(os.getenv("CHROMA_PATH", str(BASE_DIR / "chroma_db")))
COLLECTION_NAME = os.getenv("COLLECTION_NAME", "book_summaries")
TOP_K = int(os.getenv("TOP_K", "3"))

ENABLE_INPUT_FILTER = os.getenv("ENABLE_INPUT_FILTER", "true").lower() == "true"
MAX_USER_QUERY_CHARS = int(os.getenv("MAX_USER_QUERY_CHARS", "500"))
MAX_TOOL_ROUNDS = int(os.getenv("MAX_TOOL_ROUNDS", "3"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()


def validate_settings() -> None:
    """
    Verifica setarile esentiale.
    """
    if not OPENAI_API_KEY:
        raise RuntimeError(
            "Lipseste OPENAI_API_KEY. Pune cheia in fisierul .env."
        )

    if TOP_K <= 0:
        raise RuntimeError("TOP_K trebuie sa fie mai mare decat 0.")

    if MAX_USER_QUERY_CHARS < 20:
        raise RuntimeError("MAX_USER_QUERY_CHARS este prea mic.")

    if MAX_TOOL_ROUNDS <= 0:
        raise RuntimeError("MAX_TOOL_ROUNDS trebuie sa fie mai mare decat 0.")
