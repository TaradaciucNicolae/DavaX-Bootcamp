# Smart Librarian

Smart Librarian este un chatbot AI pentru recomandari de carti, construit cu:

- OpenAI pentru embeddings, raspunsuri conversationale, moderation, TTS, STT si image generation
- ChromaDB ca vector store local pentru cautare semantica
- RAG pentru selectarea candidatilor relevanti din catalog
- function calling pentru obtinerea rezumatului complet prin `get_summary_by_title(title)`
- Streamlit pentru UI web si Rich pentru UI CLI

## Ce face proiectul

Aplicatia poate primi intrebari precum:

- `Vreau o carte despre libertate si control social.`
- `Ce-mi recomanzi daca iubesc povestile fantastice?`
- `I love drama books.`
- `Vreau o carte pentru copii.`

Fluxul principal este:

1. valideaza local inputul utilizatorului
2. aplica moderation OpenAI pe input
3. cauta semantic carti relevante in ChromaDB
4. trimite doar candidatii relevanti catre model prin Responses API
5. modelul alege o singura carte si apeleaza tool-ul `get_summary_by_title`
6. aplicatia aplica moderation si pe output
7. UI afiseaza recomandarea, motivatia si rezumatul complet

## Functionalitati curente

- recomandari semantice de carti din catalogul local
- rezumat complet obtinut prin tool calling
- chatbot in Streamlit si CLI
- import de carti noi din Google Books din sidebar
- lista de carti in sidebar cu search dupa titlu, autor si gen
- click pe un titlu din sidebar pentru afisarea directa a rezumatului complet in chat
- generare audio pentru recomandari si rezumate
- input vocal cu transcriere in romana sau engleza
- generare de coperta sau scena reprezentativa pentru cartea recomandata
- filtru local de limbaj nepotrivit
- moderation OpenAI pentru input si output

## Acoperirea cerintelor din assignment

Cerinte obligatorii:

- `data/book_summaries.json` contine 10+ carti
- catalogul este incarcat in ChromaDB local, nu in OpenAI Vector Store
- embeddings-urile sunt generate cu OpenAI
- exista retriever semantic in `src/retriever.py`
- exista chatbot AI in CLI si Streamlit
- exista tool-ul `get_summary_by_title(title)` in `src/tools.py`
- tool calling-ul este orchestrat in `src/chatbot.py`
- exista README cu pasi de build, rulare si testare

Cerinte optionale:

- filtru de limbaj nepotrivit: implementat local in `src/guardrails.py` si completat cu moderation OpenAI
- import de carti noi din Google Books: implementat in sidebar-ul Streamlit
- TTS / STT / image generation: implementate in interfata Streamlit

## Structura proiectului

- `app_streamlit.py` - UI web pentru conversatie, input vocal, audio, imagini si administrarea catalogului
- `app_cli.py` - UI in terminal
- `src/chatbot.py` - orchestrare retrieval + LLM + tool calling + moderation
- `src/tools.py` - definirea si executia tool-ului `get_summary_by_title`
- `src/retriever.py` - cautare semantica in ChromaDB
- `src/vector_store.py` - initializare si rebuild vector store
- `src/data_loader.py` - incarcare si validare dataset
- `src/embeddings.py` - generare embeddings OpenAI
- `src/guardrails.py` - validare input si blocare limbaj ofensator
- `src/language_support.py` - detectie limba si normalizare a raspunsului
- `src/audio_narration.py` - generare audio pentru recomandari si rezumate
- `src/speech_transcription.py` - transcriere vocala pentru intrebari in romana si engleza
- `src/book_image_generation.py` - generare coperta si scena reprezentativa
- `src/catalog_settings_repository.py` - persistenta setarilor de import din sidebar
- `src/catalog_ingestion_service.py` - import si rebuild de catalog
- `src/prompts.py` - instructiuni pentru model si formatul contextului RAG
- `src/logger.py` - configurarea logurilor aplicatiei
- `scripts/database_loader_script.py` - colectare si normalizare de carti din Google Books
- `scripts/rebuild_index.py` - rebuild manual al indexului semantic
- `tests/` - teste automate

## Cerinte

Ai nevoie de:

- Python 3.10+
- o cheie `OPENAI_API_KEY`

## Instalare

1. Creeaza mediul virtual:

```powershell
python -m venv .venv
```

2. Activeaza mediul virtual:

```powershell
.venv\Scripts\Activate.ps1
```

3. Instaleaza dependintele:

```powershell
pip install -r requirements.txt
```

4. Configureaza fisierul `.env`:

```env
OPENAI_API_KEY=...
LLM_MODEL=gpt-4.1
EMBEDDING_MODEL=text-embedding-3-small
STT_MODEL=gpt-4o-mini-transcribe
TTS_MODEL=gpt-4o-mini-tts
TTS_VOICE=alloy
MODERATION_MODEL=omni-moderation-latest
IMAGE_MODEL=gpt-image-1-mini
IMAGE_OUTPUT_FORMAT=png
IMAGE_QUALITY=low
IMAGE_STYLE=vivid
IMAGE_COVER_SIZE=1024x1536
IMAGE_SCENE_SIZE=1536x1024
CHROMA_PATH=chroma_db
COLLECTION_NAME=book_summaries
TOP_K=3
ENABLE_INPUT_FILTER=true
MAX_USER_QUERY_CHARS=500
MAX_TOOL_ROUNDS=3
LOG_LEVEL=INFO
```

## Rulare

### Varianta Streamlit

```powershell
python -m streamlit run app_streamlit.py
```

Sau:

```powershell
python app_streamlit.py
```

### Varianta CLI

```powershell
python app_cli.py
```

La rulare, aplicatia verifica daca indexul semantic din `chroma_db/` este sincronizat cu `data/book_summaries.json` si il reconstruieste automat daca este nevoie.

## Rebuild manual al vector store-ului

Din Streamlit, rebuild-ul se face automat cand adaugi carti noi sau daca aplicatia detecteaza ca JSON-ul si indexul semantic nu mai au acelasi numar de intrari.

Sau din script:

```powershell
python scripts\rebuild_index.py
```

Sau direct din Python:

```powershell
python -c "from src.config import DATA_FILE; from src.data_loader import load_books; from src.vector_store import rebuild_vector_store; print(rebuild_vector_store(load_books(DATA_FILE)))"
```

## Import de carti noi

In sidebar-ul Streamlit exista o sectiune `Administrare catalog (Google Books API)` unde poti:

- alege genurile
- controla cate carti sa fie adaugate
- controla limba preferata pentru import
- importa carti noi din Google Books cu butonul `Adauga carti in baza de date`
- reconstrui automat indexul semantic dupa import

Setarile de import sunt pastrate local in `data/app_state.db`.

## Testare

Ruleaza toate testele:

```powershell
pytest -q
```

Suite-ul curent acopera:

- guardrails si scope detection
- moderation input/output in chatbot
- flow-ul de tool calling din chatbot
- data loading si rezolvare de titluri
- repository-ul pentru setari de catalog
- ingestia de carti noi
- generarea audio
- generarea de imagini
- speech transcription

## Exemple de intrebari

- `Vreau o carte despre libertate si control social.`
- `Ce-mi recomanzi daca iubesc povestile fantastice?`
- `Ce este 1984?`
- `Da-mi o carte SF.`
- `Vreau ceva cu mystery.`
- `I love drama books.`

## Observatii

- Catalogul principal este in `data/book_summaries.json`.
- `chroma_db/` este indexul semantic local generat din JSON.
- `logs/app.log` contine logurile locale ale aplicatiei.
- inputul vocal este limitat la romana si engleza
- generarea imaginilor poate fi blocata in unele cazuri de sistemul de safety al OpenAI
- pentru rulare este obligatoriu doar `.env`; restul fisierelor de date din proiect pot fi versionate
