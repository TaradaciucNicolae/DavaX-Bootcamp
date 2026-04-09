import logging
from logging.handlers import RotatingFileHandler

from src.config import LOG_DIR, LOG_LEVEL


def configure_logging() -> logging.Logger:
    """
    Configureaza loggerul aplicatiei.
    Folosim rotatie simpla de fisiere ca sa nu creasca logul la infinit.
    """
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("smart_librarian")

    if logger.handlers:
        return logger

    logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    )

    file_handler = RotatingFileHandler(
        LOG_DIR / "app.log",
        maxBytes=1_000_000,
        backupCount=3,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    logger.propagate = False

    return logger