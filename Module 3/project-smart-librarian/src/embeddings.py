# OpenAI client and embedding helpers used by retrieval and indexing.

from openai import OpenAI

from src.config import EMBEDDING_MODEL, OPENAI_API_KEY, validate_settings


def get_openai_client() -> OpenAI:

    # Create an OpenAI client using the key stored in .env.

    validate_settings()
    return OpenAI(api_key=OPENAI_API_KEY)


def _chunk_list(items: list[str], batch_size: int) -> list[list[str]]:

    # Split a large list into smaller batches.
    #
    # Example:
    # [a, b, c, d], batch_size=2 => [[a, b], [c, d]]
    if batch_size <= 0:
        raise ValueError("batch_size must be greater than 0.")

    return [items[i:i + batch_size] for i in range(0, len(items), batch_size)]


def embed_texts(texts: list[str], batch_size: int = 50) -> list[list[float]]:

    # Generate embeddings for a list of texts.

    # The return value is a list of float vectors in the same order.

    if not texts:
        return []

    client = get_openai_client()
    all_embeddings: list[list[float]] = []

    for batch in _chunk_list(texts, batch_size):
        response = client.embeddings.create(
            model=EMBEDDING_MODEL,
            input=batch,
            encoding_format="float",
        )

        batch_embeddings = [item.embedding for item in response.data]
        all_embeddings.extend(batch_embeddings)

    return all_embeddings


def embed_query(query: str) -> list[float]:
    # Generate an embedding for one user query.
    cleaned_query = query.strip()

    if not cleaned_query:
        raise ValueError("The query cannot be empty.")

    client = get_openai_client()

    response = client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=cleaned_query,
        encoding_format="float",
    )

    return response.data[0].embedding

