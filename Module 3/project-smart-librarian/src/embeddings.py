from openai import OpenAI

from src.config import EMBEDDING_MODEL, OPENAI_API_KEY, validate_settings


def get_openai_client() -> OpenAI:
    """
    Creeaza clientul OpenAI folosind cheia din .env.
    """
    validate_settings()
    return OpenAI(api_key=OPENAI_API_KEY)


def _chunk_list(items: list[str], batch_size: int) -> list[list[str]]:
    """
    Imparte o lista mare in batch-uri mai mici.
    Exemplu:
    [a, b, c, d], batch_size=2 => [[a, b], [c, d]]
    """
    if batch_size <= 0:
        raise ValueError("batch_size trebuie sa fie mai mare decat 0.")

    return [items[i:i + batch_size] for i in range(0, len(items), batch_size)]


def embed_texts(texts: list[str], batch_size: int = 50) -> list[list[float]]:
    """
    Genereaza embeddings pentru o lista de texte.
    Returneaza o lista de vectori (liste de float-uri).
    """
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
    """
    Genereaza embedding pentru o singura intrebare a utilizatorului.
    """
    cleaned_query = query.strip()

    if not cleaned_query:
        raise ValueError("Intrebarea nu poate fi goala.")

    client = get_openai_client()

    response = client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=cleaned_query,
        encoding_format="float",
    )

    return response.data[0].embedding