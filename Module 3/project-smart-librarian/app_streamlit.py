from base64 import b64encode
from html import escape
from hashlib import sha1
import json
from pathlib import Path
import subprocess
import sys

import requests
import streamlit as st
from streamlit.runtime.scriptrunner_utils.script_run_context import (
    get_script_run_ctx,
)

from src.audio_narration import generate_audio_narration
from src.book_image_generation import generate_book_image
from src.catalog_ingestion_service import import_books_from_settings
from src.catalog_settings_repository import (
    GENRE_QUERY_MAP,
    CatalogImportSettings,
    LANGUAGE_LABELS_BY_CODE,
    load_catalog_settings,
    save_catalog_settings,
)
from src.chatbot import chat_once
from src.config import DATA_FILE, MAX_USER_QUERY_CHARS, validate_settings
from src.data_loader import load_books
from src.embeddings import get_openai_client
from src.language_support import detect_user_language, normalize_text_to_target_language
from src.logger import configure_logging
from src.speech_transcription import (
    UnsupportedSpeechLanguageError,
    transcribe_uploaded_audio,
)
from src.tools import get_summary_by_title
from src.vector_store import get_collection_size, rebuild_vector_store

logger = configure_logging()


def _ensure_streamlit_runner() -> None:
    if get_script_run_ctx(suppress_warning=True) is not None:
        return

    subprocess.run(
        [sys.executable, "-m", "streamlit", "run", str(Path(__file__).resolve())],
        check=True,
    )
    raise SystemExit


if __name__ == "__main__":
    _ensure_streamlit_runner()


st.set_page_config(
    page_title="Smart Librarian",
    page_icon="📚",
    layout="wide",
)

STARTER_PROMPTS = [
    "Vreau o carte despre libertate si control social.",
    "Ce-mi recomanzi daca iubesc povestile fantastice?",
    "Ce este 1984?",
]

COVER_PREVIEW_WIDTH = 340
SCENE_PREVIEW_WIDTH = 720
USER_AVATAR_PATH = Path(__file__).resolve().parent / "assets" / "avatar_user_green.svg"
ASSISTANT_AVATAR_PATH = Path(__file__).resolve().parent / "assets" / "avatar_robot_blue.svg"


def inject_custom_styles() -> None:
    css = """
        <style>
        :root {
            --voice-button-width: 14.5rem;
            --voice-panel-padding: 0.15rem;
            --voice-button-height: calc(3rem - (var(--voice-panel-padding) * 2));
            --voice-status-gap: 0.4rem;
            --voice-status-size: 2.4rem;
        }

        div[data-testid="stChatInput"] {
            width: auto !important;
            max-width: none !important;
            margin-left: 0 !important;
            margin-right: calc(
                var(--voice-button-width) +
                var(--voice-status-size) +
                var(--voice-status-gap) +
                (var(--voice-panel-padding) * 2)
            ) !important;
        }

        .st-key-bottom-voice-recorder {
            position: fixed;
            right: 1rem;
            bottom: 3.25rem;
            width: calc(
                var(--voice-button-width) +
                var(--voice-status-size) +
                var(--voice-status-gap) +
                (var(--voice-panel-padding) * 2)
            );
            padding: var(--voice-panel-padding);
            box-sizing: border-box;
            background: rgba(15, 23, 42, 0.82);
            border: 1px solid rgba(148, 163, 184, 0.28);
            border-radius: 1rem;
            box-shadow: 0 10px 24px rgba(15, 23, 42, 0.18);
            backdrop-filter: blur(10px);
            z-index: 120;
        }

        .st-key-bottom-voice-recorder[data-voice-panel-mode="stop"] {
            background: rgba(220, 38, 38, 0.22);
            border-color: rgba(220, 38, 38, 0.58);
            box-shadow: 0 10px 24px rgba(185, 28, 28, 0.22);
        }

        .st-key-bottom-voice-recorder > div {
            width: 100%;
        }

        .st-key-bottom-voice-recorder [data-testid="stHorizontalBlock"] {
            align-items: center;
            gap: var(--voice-status-gap);
        }

        .st-key-bottom-voice-recorder [data-testid="column"] {
            display: flex;
            align-items: center;
        }

        .voice-status-badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: var(--voice-status-size);
            height: var(--voice-status-size);
            padding: 0;
            border-radius: 999px;
            background: rgba(15, 23, 42, 0.88);
            border: 1px solid rgba(148, 163, 184, 0.25);
            box-shadow: 0 10px 22px rgba(15, 23, 42, 0.16);
            color: #ffffff;
            backdrop-filter: blur(8px);
        }

        .voice-status-spinner {
            width: 0.95rem;
            height: 0.95rem;
            border-radius: 999px;
            border: 2px solid rgba(255, 255, 255, 0.28);
            border-top-color: #ffffff;
            animation: voice-status-spin 0.8s linear infinite;
            flex: 0 0 auto;
        }

        @keyframes voice-status-spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }

        .action-loading-indicator {
            display: inline-flex;
            align-items: center;
            gap: 0.55rem;
            padding: 0.55rem 0.8rem;
            border-radius: 0.8rem;
            background: rgba(15, 23, 42, 0.72);
            border: 1px solid rgba(148, 163, 184, 0.22);
            color: #ffffff;
            margin-top: 0.45rem;
            margin-bottom: 0.35rem;
        }

        .action-loading-text {
            font-size: 0.93rem;
            font-weight: 600;
            line-height: 1.15;
        }

        .st-key-bottom-voice-recorder label,
        .st-key-bottom-voice-recorder [data-testid="stAudioInputWaveSurfer"],
        .st-key-bottom-voice-recorder [data-testid="stAudioInputWaveformTimeCode"] {
            display: none !important;
        }

        .st-key-bottom-voice-recorder [data-testid="stAudioInput"] {
            width: 100%;
        }

        .st-key-bottom-voice-recorder [data-testid="stAudioInput"] > div {
            min-height: 0 !important;
            padding: 0 !important;
            margin: 0 !important;
            background: transparent !important;
            border: none !important;
            overflow: visible !important;
        }

        .st-key-bottom-voice-recorder [data-testid="stAudioInputActionButton"] {
            width: 100% !important;
            min-width: 100% !important;
        }

        .st-key-bottom-voice-recorder [data-testid="stAudioInputActionButton"] > button,
        .st-key-bottom-voice-recorder [data-testid="stAudioInputActionButton"] {
            min-height: var(--voice-button-height) !important;
            height: var(--voice-button-height) !important;
            width: 100% !important;
            border-radius: 0.75rem !important;
        }

        .st-key-bottom-voice-recorder [data-voice-mode="start"] {
            background: var(--secondary-background-color, #262730) !important;
            border-color: rgba(250, 250, 250, 0.2) !important;
            color: inherit !important;
        }

        .st-key-bottom-voice-recorder [data-voice-mode="start"]:hover {
            border-color: rgba(250, 250, 250, 0.32) !important;
        }

        .st-key-bottom-voice-recorder [data-voice-mode="stop"] {
            background: #dc2626 !important;
            border-color: #dc2626 !important;
            color: #ffffff !important;
        }

        .st-key-bottom-voice-recorder [data-voice-mode="stop"]:hover {
            background: #b91c1c !important;
            border-color: #b91c1c !important;
            color: #ffffff !important;
        }

        .st-key-bottom-voice-recorder .voice-button-label {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 100%;
            font-weight: 600;
            line-height: 1.1;
        }

        .st-key-bottom-voice-recorder .voice-button-content {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 0.45rem;
            width: 100%;
        }

        .st-key-bottom-voice-recorder .voice-button-icon {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 1.05rem;
            height: 1.05rem;
            flex: 0 0 auto;
        }

        .st-key-bottom-voice-recorder .voice-button-icon svg {
            width: 100%;
            height: 100%;
            display: block;
        }

        .st-key-bottom-voice-recorder .voice-button-text {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            white-space: nowrap;
        }

        @media (max-width: 900px) {
            :root {
                --voice-button-width: 9rem;
            }
        }

        @media (max-width: 720px) {
            :root {
                --voice-button-width: 8.25rem;
                --voice-status-gap: 0.25rem;
                --voice-status-size: 2.15rem;
            }
        }

        .full-summary-card {
            border: 1px solid #22c55e;
            border-radius: 0.85rem;
            padding: 1rem 1.1rem;
            background: transparent;
            color: #ffffff;
        }

        .full-summary-card,
        .full-summary-card * {
            color: #ffffff !important;
        }

        .full-summary-card p {
            margin: 0;
            line-height: 1.65;
        }

        </style>
        """
    st.markdown(css, unsafe_allow_html=True)


def ensure_session_state() -> None:
    defaults = {
        "messages": [],
        "vector_store_ready": False,
        "startup_error": None,
        "app_bootstrapped": False,
        "pending_prompt": None,
        "pending_catalog_summary": None,
        "message_counter": 0,
        "audio_by_message": {},
        "images_by_message": {},
        "voice_input_nonce": 0,
        "last_voice_audio_hash": None,
    }

    for key, value in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = value

    counter = st.session_state.get("message_counter", 0)
    for message in st.session_state.get("messages", []):
        existing_message_id = message.get("message_id")
        if isinstance(existing_message_id, str) and existing_message_id.startswith("msg_"):
            suffix = existing_message_id.removeprefix("msg_")
            if suffix.isdigit():
                counter = max(counter, int(suffix))
            continue

        counter += 1
        message["message_id"] = f"msg_{counter}"

    st.session_state.message_counter = counter


def create_message_id() -> str:
    st.session_state.message_counter += 1
    return f"msg_{st.session_state.message_counter}"


def get_chat_avatar(role: str) -> str:
    if role == "user":
        return str(USER_AVATAR_PATH)
    return str(ASSISTANT_AVATAR_PATH)


def bootstrap_vector_store() -> None:
    if st.session_state.app_bootstrapped:
        return

    try:
        validate_settings()
        books = load_books(DATA_FILE)
        expected_count = len(books)
        current_count = get_collection_size()

        # Daca JSON-ul local si indexul semantic nu mai au acelasi numar de carti,
        # refacem indexul ca sa evitam rezultate stale dupa stergeri/importuri.
        if current_count != expected_count:
            current_count = rebuild_vector_store(books)

        st.session_state.vector_store_ready = True
        st.session_state.startup_error = None
    except Exception as exc:
        logger.exception("bootstrap_vector_store_failed")
        st.session_state.vector_store_ready = False
        st.session_state.startup_error = str(exc)
    finally:
        st.session_state.app_bootstrapped = True


def build_error_message(
    text: str,
    *,
    matches: list[dict] | None = None,
    tool_calls: list[dict] | None = None,
    display: dict | None = None,
    response_language: str = "ro",
) -> dict:
    return {
        "role": "assistant",
        "kind": "error",
        "content": text,
        "matches": matches or [],
        "tool_calls": tool_calls or [],
        "response_language": response_language,
        "display": display,
    }


def build_summary_only_message(
    text: str,
    *,
    title: str = "",
    author: str = "",
    genres: list[str] | None = None,
    response_language: str = "ro",
) -> dict:
    return {
        "role": "assistant",
        "kind": "summary_only",
        "content": text,
        "matches": [],
        "tool_calls": [],
        "response_language": response_language,
        "display": {
            "recommended_title": title,
            "recommended_author": author,
            "genres": genres or [],
            "why_this_book": "",
            "full_summary": text,
        },
    }


def build_assistant_message(result: dict) -> dict:
    status = result.get("status")
    response_language = result.get("response_language", "ro")

    if status == "blocked_input":
        return {
            "role": "assistant",
            "kind": "blocked",
            "content": result.get("final_answer", "Mesaj blocat."),
            "matches": [],
            "tool_calls": [],
            "response_language": response_language,
            "display": None,
        }

    if status == "no_matches":
        return {
            "role": "assistant",
            "kind": "no_matches",
            "content": result.get("final_answer", "Nu am gasit rezultate."),
            "matches": [],
            "tool_calls": [],
            "response_language": response_language,
            "display": None,
        }

    if status == "out_of_scope":
        return {
            "role": "assistant",
            "kind": "out_of_scope",
            "content": result.get("final_answer", "Intrebarea nu este in domeniul aplicatiei."),
            "matches": [],
            "tool_calls": [],
            "response_language": response_language,
            "display": None,
        }

    if status == "error":
        return build_error_message(
            result.get("final_answer", "A aparut o eroare interna."),
            matches=result.get("matches", []),
            tool_calls=result.get("tool_calls", []),
            display=result.get("display"),
            response_language=response_language,
        )

    return {
        "role": "assistant",
        "kind": "assistant",
        "content": result.get("final_answer", ""),
        "matches": result.get("matches", []),
        "tool_calls": result.get("tool_calls", []),
        "response_language": response_language,
        "display": result.get("display") or {},
    }


def get_response_labels(language: str) -> dict[str, str]:
    if language == "en":
        return {
            "recommendation": "Recommendation",
            "title": "Title",
            "author": "Author",
            "genres": "Genres",
            "why": "Why It Fits",
            "summary": "Full Summary",
            "summary_unavailable": "Summary unavailable.",
        }

    return {
        "recommendation": "Recomandare",
        "title": "Titlu",
        "author": "Autor",
        "genres": "Genuri",
        "why": "De ce se potriveste",
        "summary": "Rezumat complet",
        "summary_unavailable": "Rezumat indisponibil.",
    }


def get_audio_labels(language: str) -> dict[str, str]:
    if language == "en":
        return {
            "generate": "Listen to this recommendation",
            "regenerate": "Regenerate audio",
            "download": "Download audio",
            "spinner": "Generating audio narration...",
            "error": "I couldn't generate the audio right now. Please try again.",
        }

    return {
        "generate": "Asculta recomandarea",
        "regenerate": "Genereaza din nou audio",
        "download": "Descarca audio",
        "spinner": "Generez varianta audio...",
        "error": "Nu am putut genera audio momentan. Incearca din nou.",
    }


def get_voice_labels(language: str) -> dict[str, str]:
    if language == "en":
        return {
            "toggle_open": "Vorbeste / Speak",
            "toggle_close": "Stop & Send",
            "recorder_label": "Record your question",
            "recorder_help": "Press the microphone, speak your question, then submit the recording.",
            "unsupported_language": "I can transcribe only Romanian or English voice messages.",
            "error": "I couldn't transcribe the audio right now. Please try again.",
        }

    return {
        "toggle_open": "Vorbeste / Speak",
        "toggle_close": "Stop & Send",
        "recorder_label": "Inregistreaza intrebarea la microfon",
        "recorder_help": "Apasa pe microfon, spune intrebarea, apoi trimite inregistrarea pentru transcriere.",
        "unsupported_language": "Pot transcrie doar mesaje vocale in romana sau engleza.",
        "error": "Nu am putut transcrie mesajul audio momentan. Incearca din nou.",
    }


def get_image_labels(language: str) -> dict[str, str]:
    if language == "en":
        return {
            "cover_button": "Generate cover",
            "scene_button": "Generate representative scene",
            "download": "Download image",
            "cover_spinner": "Generating representative cover...",
            "scene_spinner": "Generating representative scene...",
            "error": "I couldn't generate the image right now. Please try again.",
            "cover_caption": "Generated cover concept",
            "scene_caption": "Generated representative scene",
        }

    return {
        "cover_button": "Genereaza coperta",
        "scene_button": "Genereaza scena reprezentativa",
        "download": "Descarca imaginea",
        "cover_spinner": "Generez coperta reprezentativa...",
        "scene_spinner": "Generez scena reprezentativa...",
        "error": "Nu am putut genera imaginea momentan. Incearca din nou.",
        "cover_caption": "Coperta generata pentru recomandare",
        "scene_caption": "Scena reprezentativa generata pentru carte",
    }


def render_full_summary(summary_text: str) -> None:
    safe_summary = escape(summary_text).replace("\n", "<br>")
    st.markdown(
        f"""
        <div class="full-summary-card">
            <p>{safe_summary}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_centered_cover_image(image_payload: dict, caption: str) -> None:
    image_base64 = b64encode(image_payload["image_bytes"]).decode("ascii")
    safe_caption = escape(caption)
    st.markdown(
        f"""
        <div style="display:flex; flex-direction:column; align-items:center; width:100%;">
            <img
                src="data:{image_payload['mime_type']};base64,{image_base64}"
                alt="{safe_caption}"
                style="width:{COVER_PREVIEW_WIDTH}px; max-width:100%; height:auto; border-radius:0.5rem;"
            />
            <p style="margin-top:0.6rem; text-align:center;">{safe_caption}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_centered_scene_image(image_payload: dict, caption: str) -> None:
    image_base64 = b64encode(image_payload["image_bytes"]).decode("ascii")
    safe_caption = escape(caption)
    st.markdown(
        f"""
        <div style="display:flex; flex-direction:column; align-items:center; width:100%;">
            <img
                src="data:{image_payload['mime_type']};base64,{image_base64}"
                alt="{safe_caption}"
                style="width:{SCENE_PREVIEW_WIDTH}px; max-width:100%; height:auto; border-radius:0.5rem;"
            />
            <p style="margin-top:0.6rem; text-align:center;">{safe_caption}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def get_interface_language() -> str:
    for message in reversed(st.session_state.get("messages", [])):
        if message.get("role") == "user":
            return detect_user_language(message.get("content", ""))

        response_language = message.get("response_language")
        if response_language in {"ro", "en"}:
            return response_language

    return "ro"


def render_voice_input_controls() -> None:
    language = get_interface_language()
    labels = get_voice_labels(language) or get_voice_labels("ro")
    is_ready = st.session_state.vector_store_ready
    preferred_language = language if language in {"ro", "en"} else "ro"

    button_column, status_column = st.columns([17, 3], gap="small")

    recorder_key = f"voice_input_recorder_{st.session_state.voice_input_nonce}"
    with button_column:
        recorded_audio = st.audio_input(
            labels["recorder_label"],
            help=labels["recorder_help"],
            key=recorder_key,
            disabled=not is_ready,
            label_visibility="collapsed",
            width="stretch",
        )
    if recorded_audio is None:
        return

    audio_bytes = recorded_audio.getvalue()
    if not audio_bytes:
        return

    audio_hash = sha1(audio_bytes).hexdigest()
    if audio_hash == st.session_state.last_voice_audio_hash:
        return

    with status_column:
        st.markdown(
            f"""
            <div class="voice-status-badge">
                <span class="voice-status-spinner" aria-hidden="true"></span>
            </div>
            """,
            unsafe_allow_html=True,
        )

    try:
        transcript = transcribe_uploaded_audio(
            recorded_audio,
            preferred_language=preferred_language,
        )
    except UnsupportedSpeechLanguageError:
        st.session_state.last_voice_audio_hash = audio_hash
        st.error(labels["unsupported_language"])
        return
    except Exception:
        logger.exception("voice_transcription_failed")
        st.session_state.last_voice_audio_hash = audio_hash
        st.error(labels["error"])
        return

    st.session_state.last_voice_audio_hash = audio_hash
    st.session_state.voice_input_nonce += 1
    st.session_state.pending_prompt = transcript
    st.rerun()


def render_voice_recorder_bridge() -> None:
    labels = get_voice_labels(get_interface_language())
    bridge_html = f"""
    <script>
    (() => {{
        const rootSelector = ".st-key-bottom-voice-recorder [data-testid='stAudioInput']";
        const startText = {json.dumps(labels["toggle_open"])};
        const stopText = {json.dumps(labels["toggle_close"])};
        const micIcon = `
            <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                <path fill="currentColor" d="M12 14a3 3 0 0 0 3-3V5a3 3 0 1 0-6 0v6a3 3 0 0 0 3 3Zm5-3a1 1 0 1 0-2 0 3 3 0 1 1-6 0 1 1 0 1 0-2 0 5 5 0 0 0 4 4.9V21a1 1 0 1 0 2 0v-2.1A5 5 0 0 0 17 11Z"/>
            </svg>
        `;

        const syncButton = () => {{
            const root = document.querySelector(rootSelector);
            const button = root?.querySelector("[data-testid='stAudioInputActionButton']");
            if (!button) {{
                return false;
            }}

            const ariaLabel = button.getAttribute("aria-label") || "";
            const isStopMode = ariaLabel === "Stop recording";
            const targetText = isStopMode ? stopText : startText;
            const panel = root.closest(".st-key-bottom-voice-recorder");

            button.setAttribute("data-voice-mode", isStopMode ? "stop" : "start");
            panel?.setAttribute("data-voice-panel-mode", isStopMode ? "stop" : "start");
            button.innerHTML =
                '<span class="voice-button-label">' +
                    '<span class="voice-button-content">' +
                        '<span class="voice-button-icon">' + micIcon + '</span>' +
                        '<span class="voice-button-text">' + targetText + '</span>' +
                    '</span>' +
                '</span>';

            const siblingButtons = root.querySelectorAll("[data-testid='stAudioInputActionButton']");
            siblingButtons.forEach((item, index) => {{
                if (index > 0) {{
                    item.style.display = "none";
                }}
            }});

            const extraControls = root.querySelectorAll(
                "[aria-label='Play'], [aria-label='Pause'], [aria-label='Reset'], [aria-label='Download as WAV'], [aria-label='Clear recording']"
            );
            extraControls.forEach((item) => {{
                item.style.display = "none";
            }});

            return true;
        }};

        const boot = () => {{
            const root = document.querySelector(rootSelector);
            const button = root?.querySelector("[data-testid='stAudioInputActionButton']");
            if (!root || !button) {{
                window.setTimeout(boot, 100);
                return;
            }}

            syncButton();

            const observer = new MutationObserver(() => {{
                syncButton();
            }});

            observer.observe(root, {{
                subtree: true,
                childList: true,
                attributes: true,
                attributeFilter: ["aria-label"],
            }});
        }};

        window.setTimeout(boot, 0);
    }})();
    </script>
    """
    st.html(bridge_html, width="content", unsafe_allow_javascript=True)


@st.fragment
def render_voice_controls() -> None:
    with st.container(key="bottom-voice-recorder"):
        render_voice_input_controls()

    render_voice_recorder_bridge()


@st.fragment
def render_audio_controls(message: dict) -> None:
    display = message.get("display") or {}
    if not display:
        return

    message_id = message.get("message_id")
    if not message_id:
        return

    labels = get_audio_labels(message.get("response_language", "ro"))
    cached_audio = st.session_state.audio_by_message.get(message_id)

    button_label = labels["regenerate"] if cached_audio else labels["generate"]
    should_rerun = False
    if st.button(button_label, key=f"audio_generate_{message_id}", use_container_width=True):
        status_placeholder = st.empty()
        status_placeholder.markdown(
            f"""
            <div class="action-loading-indicator">
                <span class="voice-status-spinner" aria-hidden="true"></span>
                <span class="action-loading-text">{escape(labels["spinner"])}</span>
            </div>
            """,
            unsafe_allow_html=True,
        )
        try:
            cached_audio = generate_audio_narration(message)
            st.session_state.audio_by_message[message_id] = cached_audio
            should_rerun = True
        except Exception:
            logger.exception("audio_generation_failed | message_id=%s", message_id)
            st.error(labels["error"])
            cached_audio = st.session_state.audio_by_message.get(message_id)
        finally:
            status_placeholder.empty()

    if should_rerun:
        st.rerun()

    if not cached_audio:
        return

    st.audio(cached_audio["audio_bytes"], format=cached_audio["mime_type"])
    st.download_button(
        labels["download"],
        data=cached_audio["audio_bytes"],
        file_name=cached_audio["file_name"],
        mime=cached_audio["mime_type"],
        key=f"audio_download_{message_id}",
        use_container_width=True,
    )


@st.fragment
def render_image_controls(message: dict) -> None:
    display = message.get("display") or {}
    if not display:
        return

    message_id = message.get("message_id")
    if not message_id:
        return

    labels = get_image_labels(message.get("response_language", "ro"))
    cached_images = st.session_state.images_by_message.setdefault(message_id, {})
    status_placeholder = st.empty()

    cover_column, scene_column = st.columns(2)
    with cover_column:
        if st.button(
            labels["cover_button"],
            key=f"image_cover_{message_id}",
            use_container_width=True,
        ):
            status_placeholder.markdown(
                f"""
                <div class="action-loading-indicator">
                    <span class="voice-status-spinner" aria-hidden="true"></span>
                    <span class="action-loading-text">{escape(labels["cover_spinner"])}</span>
                </div>
                """,
                unsafe_allow_html=True,
            )
            try:
                cached_images["cover"] = generate_book_image(message, "cover")
            except Exception:
                logger.exception("image_generation_failed | message_id=%s | variant=cover", message_id)
                st.error(labels["error"])
            finally:
                status_placeholder.empty()

    with scene_column:
        if st.button(
            labels["scene_button"],
            key=f"image_scene_{message_id}",
            use_container_width=True,
        ):
            status_placeholder.markdown(
                f"""
                <div class="action-loading-indicator">
                    <span class="voice-status-spinner" aria-hidden="true"></span>
                    <span class="action-loading-text">{escape(labels["scene_spinner"])}</span>
                </div>
                """,
                unsafe_allow_html=True,
            )
            try:
                cached_images["scene"] = generate_book_image(message, "scene")
            except Exception:
                logger.exception("image_generation_failed | message_id=%s | variant=scene", message_id)
                st.error(labels["error"])
            finally:
                status_placeholder.empty()

    for variant in ("cover", "scene"):
        image_payload = cached_images.get(variant)
        if not image_payload:
            continue

        caption = labels["cover_caption"] if variant == "cover" else labels["scene_caption"]
        if variant == "cover":
            render_centered_cover_image(image_payload, caption)

            left_spacer, content_column, right_spacer = st.columns([1, 1.1, 1])
            del left_spacer, right_spacer

            with content_column:
                st.download_button(
                    labels["download"],
                    data=image_payload["image_bytes"],
                    file_name=image_payload["file_name"],
                    mime=image_payload["mime_type"],
                    key=f"image_download_{variant}_{message_id}",
                    use_container_width=True,
                )
            continue

        render_centered_scene_image(image_payload, caption)
        st.download_button(
            labels["download"],
            data=image_payload["image_bytes"],
            file_name=image_payload["file_name"],
            mime=image_payload["mime_type"],
            key=f"image_download_{variant}_{message_id}",
            use_container_width=True,
        )


def render_assistant_message(message: dict) -> None:
    kind = message.get("kind", "assistant")

    if kind == "error":
        st.error(message.get("content", "A aparut o eroare interna."))
        return

    if kind == "blocked":
        st.error(message.get("content", "Mesaj blocat."))
        return

    if kind == "no_matches":
        st.warning(message.get("content", "Nu am gasit rezultate."))
        return

    if kind == "out_of_scope":
        st.info(message.get("content", "Intrebarea nu este in domeniul aplicatiei."))
        return

    if kind == "summary_only":
        display = message.get("display") or {}
        labels = get_response_labels(message.get("response_language", "ro"))
        st.markdown(f"{labels['title']}: {display.get('recommended_title') or '-'}")
        st.markdown(f"{labels['author']}: {display.get('recommended_author') or '-'}")
        st.markdown(
            f"{labels['genres']}: {', '.join(display.get('genres') or []) or '-'}"
        )
        st.markdown(f"### {labels['summary']}")
        render_full_summary(display.get("full_summary") or message.get("content", "Rezumat indisponibil."))
        render_image_controls(message)
        render_audio_controls(message)
        return

    display = message.get("display") or {}
    if not display:
        st.markdown(message.get("content", "Nu am putut construi raspunsul final."))
        return

    labels = get_response_labels(message.get("response_language", "ro"))

    st.markdown(f"### {labels['recommendation']}")
    st.markdown(f"{labels['title']}: {display.get('recommended_title') or '-'}")
    st.markdown(f"{labels['author']}: {display.get('recommended_author') or '-'}")
    st.markdown(
        f"{labels['genres']}: {', '.join(display.get('genres') or []) or '-'}"
    )

    st.markdown(f"### {labels['why']}")
    st.markdown(display.get("why_this_book") or message.get("content", "-"))

    st.markdown(f"### {labels['summary']}")
    render_full_summary(display.get("full_summary") or labels["summary_unavailable"])
    render_image_controls(message)
    render_audio_controls(message)


def render_history() -> None:
    for message in st.session_state.messages:
        role = message.get("role", "assistant")

        with st.chat_message(role, avatar=get_chat_avatar(role)):
            if role == "user":
                st.markdown(message.get("content", ""))
            else:
                render_assistant_message(message)


def render_catalog_list_sidebar() -> None:
    try:
        books = sorted(
            load_books(DATA_FILE),
            key=lambda book: (book.title.casefold(), book.author.casefold()),
        )
    except Exception:
        logger.exception("catalog_sidebar_list_failed")
        st.error("Nu am putut incarca lista cartilor din baza de date.")
        return

    total_books = len(books)
    st.subheader(f"Carti in baza de date ({total_books})")

    if not books:
        st.caption("Nu exista momentan carti in catalogul local.")
        return

    search_text = st.text_input(
        "Cauta in catalog",
        value="",
        placeholder="Titlu, autor sau gen...",
        key="catalog_sidebar_search",
    ).strip()
    st.caption("Apasa pe un titlu ca sa vezi rezumatul in chat.")

    if search_text:
        normalized_search = search_text.casefold()
        books = [
            book
            for book in books
            if normalized_search in book.title.casefold()
            or normalized_search in book.author.casefold()
            or any(normalized_search in genre.casefold() for genre in book.genres)
        ]

    if not books:
        st.caption("Nu am gasit carti care sa se potriveasca filtrului introdus.")
        return

    header_title, header_author, header_genres = st.columns([1.35, 1, 1.15], gap="small")
    with header_title:
        st.markdown("**Nume**")
    with header_author:
        st.markdown("**Autor**")
    with header_genres:
        st.markdown("**Genuri**")

    for book in books:
        title_column, author_column, genres_column = st.columns([1.35, 1, 1.15], gap="small")

        with title_column:
            if st.button(
                book.title,
                key=f"catalog_summary_{book.id}",
                use_container_width=True,
                disabled=not st.session_state.vector_store_ready,
            ):
                st.session_state.pending_catalog_summary = {
                    "title": book.title,
                    "author": book.author,
                    "genres": list(book.genres),
                }

        with author_column:
            st.markdown(
                f"<div style='font-size:0.82rem; line-height:1.35;'>{escape(book.author)}</div>",
                unsafe_allow_html=True,
            )

        with genres_column:
            st.markdown(
                f"<div style='font-size:0.82rem; line-height:1.35;'>{escape(', '.join(book.genres))}</div>",
                unsafe_allow_html=True,
            )


def render_starter_prompts() -> None:
    outer_left, center_column, outer_right = st.columns([1, 2.4, 1])
    del outer_left, outer_right

    with center_column:
        st.caption("Alege una dintre intrebarile de mai jos sau scrie una noua.")

        for prompt in STARTER_PROMPTS:
            if st.button(prompt, use_container_width=True):
                st.session_state.pending_prompt = prompt
                st.rerun()


def render_catalog_admin() -> None:
    st.subheader("Administrare catalog (Google Books API)")

    current_settings = load_catalog_settings()

    selected_labels = st.multiselect(
        "Genuri",
        options=list(GENRE_QUERY_MAP.keys()),
        default=current_settings.selected_labels,
        help="Alegi ce categorii de carti vrei sa adaugi in catalog.",
    )

    books_per_genre = st.number_input(
        "Cate carti dorim sa adaugam ?",
        min_value=1,
        max_value=40,
        value=current_settings.books_per_genre,
        step=1,
        help="Valoarea controleaza cate rezultate bune pastrezi pentru fiecare gen.",
    )

    language_restrict = st.selectbox(
        "Limba",
        options=list(LANGUAGE_LABELS_BY_CODE.keys()),
        index=["en", "ro", "any"].index(current_settings.language_restrict),
        format_func=lambda code: LANGUAGE_LABELS_BY_CODE.get(code, code),
    )

    max_pages_per_query = st.slider(
        "Cate pagini Google Books sa parcurga",
        min_value=1,
        max_value=10,
        value=current_settings.max_pages_per_query,
    )

    settings = CatalogImportSettings(
        selected_labels=selected_labels,
        books_per_genre=int(books_per_genre),
        language_restrict=language_restrict,
        max_pages_per_query=int(max_pages_per_query),
    )

    if st.button("Adauga carti in baza de date"):
        with st.spinner("Import carti noi si reconstruiesc indexul semantic..."):
            try:
                save_catalog_settings(settings)
                result = import_books_from_settings(settings)
            except requests.exceptions.HTTPError as exc:
                status = exc.response.status_code if exc.response is not None else None
                logger.exception("catalog_import_http_failed")
                if status in {429, 500, 502, 503, 504}:
                    st.warning("Google Books este temporar indisponibil. Incearca din nou.")
                    return
                st.error(f"Importul a esuat: {exc}")
                return
            except requests.exceptions.RequestException as exc:
                logger.exception("catalog_import_request_failed")
                st.warning(f"Nu am putut contacta Google Books: {exc}")
                return
            except Exception as exc:
                logger.exception("catalog_import_failed")
                st.error(f"Importul a esuat: {exc}")
                return

        st.session_state.vector_store_ready = True
        st.session_state.startup_error = None
        st.success(
            f"Am adaugat/actualizat {result['new_items_in_this_run']} carti. "
            f"Total in catalog: {result['total_items_in_json']}."
        )


def render_sidebar() -> None:
    with st.sidebar:
        if st.button("Sterge conversatia", use_container_width=True):
            st.session_state.messages = []
            st.rerun()

        st.markdown("---")

        if not st.session_state.vector_store_ready:
            st.error("Catalogul semantic nu este disponibil.")

        if st.session_state.get("startup_error"):
            st.caption("Ultima eroare de initializare:")
            st.error(st.session_state.startup_error)

        render_catalog_admin()
        st.markdown("---")

        render_catalog_list_sidebar()


def process_user_prompt(prompt: str) -> None:
    prompt_language = detect_user_language(prompt)
    loading_text = "Finding the best recommendation for you..." if prompt_language == "en" else (
        "Caut cea mai buna recomandare pentru tine..."
    )

    user_message = {
        "message_id": create_message_id(),
        "role": "user",
        "content": prompt,
    }
    st.session_state.messages.append(user_message)

    with st.chat_message("user", avatar=get_chat_avatar("user")):
        st.markdown(prompt)

    with st.chat_message("assistant", avatar=get_chat_avatar("assistant")):
        with st.spinner(loading_text):
            try:
                result = chat_once(prompt)
                assistant_message = build_assistant_message(result)
            except Exception:
                logger.exception("streamlit_chat_failed")
                assistant_message = build_error_message(
                    "A aparut o eroare temporara la procesarea intrebarii. Incearca din nou."
                )

        assistant_message["message_id"] = create_message_id()
        render_assistant_message(assistant_message)

    st.session_state.messages.append(assistant_message)


def process_catalog_summary_request(title: str, author: str, genres: list[str] | None = None) -> None:
    response_language = get_interface_language()
    loading_text = "Loading full summary..." if response_language == "en" else "Incarc rezumatul complet..."

    with st.chat_message("assistant", avatar=get_chat_avatar("assistant")):
        with st.spinner(loading_text):
            try:
                summary_text = get_summary_by_title(title)
                normalized_summary = summary_text.strip().casefold()

                if normalized_summary.startswith("eroare:") or normalized_summary.startswith(
                    "nu am gasit in baza locala"
                ):
                    assistant_message = build_error_message(
                        summary_text,
                        response_language=response_language,
                    )
                else:
                    client = get_openai_client()
                    summary_text = normalize_text_to_target_language(
                        client,
                        summary_text,
                        response_language,
                    )
                    assistant_message = build_summary_only_message(
                        summary_text,
                        title=title,
                        author=author,
                        genres=genres,
                        response_language=response_language,
                    )
            except Exception:
                logger.exception("catalog_summary_click_failed | title=%s | author=%s", title, author)
                error_text = (
                    "I couldn't load the full summary right now. Please try again."
                    if response_language == "en"
                    else "Nu am putut incarca rezumatul complet momentan. Incearca din nou."
                )
                assistant_message = build_error_message(
                    error_text,
                    response_language=response_language,
                )

        assistant_message["message_id"] = create_message_id()
        render_assistant_message(assistant_message)

    st.session_state.messages.append(assistant_message)


def main() -> None:
    ensure_session_state()
    inject_custom_styles()

    with st.spinner("Initializez catalogul semantic..."):
        bootstrap_vector_store()

    render_sidebar()
    st.title("Smart Librarian")

    if st.session_state.get("startup_error"):
        st.error(
            "Aplicatia nu a putut initializa vector store-ul. "
            "Rezolva eroarea din sidebar si incearca din nou."
        )
        st.stop()

    prompt = st.chat_input(
        "Intreaba despre o tema, un gen sau o carte... / Ask about a topic, a genre, or a book...",
        max_chars=MAX_USER_QUERY_CHARS,
        disabled=not st.session_state.vector_store_ready,
    )

    render_voice_controls()

    pending_prompt = st.session_state.pending_prompt
    pending_catalog_summary = st.session_state.pending_catalog_summary

    render_history()

    if (
        not st.session_state.messages
        and not prompt
        and not pending_prompt
        and not pending_catalog_summary
    ):
        render_starter_prompts()

    if pending_catalog_summary:
        st.session_state.pending_catalog_summary = None
        process_catalog_summary_request(
            pending_catalog_summary["title"],
            pending_catalog_summary["author"],
            pending_catalog_summary.get("genres"),
        )
        return

    active_prompt = pending_prompt or prompt

    if not active_prompt:
        return

    if pending_prompt:
        st.session_state.pending_prompt = None

    process_user_prompt(active_prompt)


if __name__ == "__main__":
    main()
