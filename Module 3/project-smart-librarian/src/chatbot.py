import json
import unicodedata
from typing import Any

from src.config import LLM_MODEL, MAX_TOOL_ROUNDS, MODERATION_MODEL, TOP_K
from src.embeddings import get_openai_client
from src.data_loader import resolve_catalog_title
from src.guardrails import (
    infer_book_query_from_preference,
    is_book_related_query,
    normalize_book_query_aliases,
    normalize_user_text,
    validate_user_query,
)
from src.language_support import (
    detect_user_language,
    get_language_name,
    normalize_text_to_target_language,
)
from src.logger import configure_logging
from src.prompts import BOOK_RECOMMENDER_INSTRUCTIONS, build_rag_user_message
from src.retriever import search_books
from src.tools import GET_SUMMARY_BY_TITLE_TOOL, execute_tool_call

logger = configure_logging()
CLASSIC_BLOCKED_MESSAGE = (
    "Iti pot recomanda carti cu placere, dar te rog sa reformulezi "
    "fara limbaj ofensator."
)
CHILD_AUDIENCE_MARKERS = (
    "pentru copii",
    "pentru copil",
    "copii",
    "children",
    "for kids",
    "for children",
    "kids",
    "young readers",
)
HIGH_RISK_CONTENT_MARKERS = (
    "sexual",
    "sex",
    "explicit",
    "porn",
    "nude",
    "nudity",
    "abuse",
    "abuz",
    "abuzuri",
    "molest",
    "rape",
    "groom",
    "violent",
    "violence",
    "violenta",
    "violență",
    "graphic",
    "gore",
    "weapon",
    "weapons",
    "arma",
    "arme",
    "armă",
    "knife",
    "gun",
    "guns",
    "murder",
    "kill",
    "killing",
    "self-harm",
    "self harm",
    "suicide",
    "drug",
    "drugs",
    "drog",
    "droguri",
    "droguri",
)


def _extract_function_calls(response: Any) -> list[Any]:
    function_calls: list[Any] = []

    for item in getattr(response, "output", []) or []:
        if getattr(item, "type", None) == "function_call":
            function_calls.append(item)

    return function_calls


def _safe_preview(text: str, limit: int = 80) -> str:
    preview = text.replace("\n", " ").strip()
    if len(preview) <= limit:
        return preview
    return preview[:limit] + "..."


def _moderation_results_flagged(results: list[Any]) -> bool:
    return any(bool(getattr(result, "flagged", False)) for result in results)


def _normalize_for_risk_scan(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", normalize_user_text(text).casefold())
    return "".join(char for char in normalized if not unicodedata.combining(char))


def _contains_high_risk_markers(text: str) -> bool:
    normalized_text = _normalize_for_risk_scan(text)
    return any(marker in normalized_text for marker in HIGH_RISK_CONTENT_MARKERS)


def _is_benign_child_book_content(texts: list[str]) -> bool:
    combined_text = normalize_user_text(" ".join(texts)).casefold()
    if not combined_text:
        return False

    if not is_book_related_query(combined_text):
        return False

    if not any(marker in combined_text for marker in CHILD_AUDIENCE_MARKERS):
        return False

    return not _contains_high_risk_markers(combined_text)


def _is_benign_general_book_content(texts: list[str]) -> bool:
    combined_text = normalize_user_text(" ".join(texts)).casefold()
    if not combined_text:
        return False

    if not is_book_related_query(combined_text):
        return False

    return not _contains_high_risk_markers(combined_text)


def _is_moderation_flagged(
    client: Any,
    texts: list[str],
    *,
    stage: str,
    benign_context_texts: list[str] | None = None,
) -> bool:
    cleaned_texts = [text.strip() for text in texts if text and text.strip()]
    if not cleaned_texts:
        return False

    moderations_api = getattr(client, "moderations", None)
    if moderations_api is None:
        return False

    moderation_input: str | list[str]
    if len(cleaned_texts) == 1:
        moderation_input = cleaned_texts[0]
    else:
        moderation_input = cleaned_texts

    try:
        response = moderations_api.create(
            model=MODERATION_MODEL,
            input=moderation_input,
        )
    except Exception:
        logger.exception("moderation_check_failed | stage=%s", stage)
        return False

    flagged = _moderation_results_flagged(list(getattr(response, "results", []) or []))
    if not flagged:
        return False

    benign_check_texts = cleaned_texts + [
        text.strip() for text in (benign_context_texts or []) if text and text.strip()
    ]

    if _is_benign_child_book_content(benign_check_texts):
        logger.info(
            "moderation_false_positive_ignored | stage=%s | preview=%s",
            stage,
            _safe_preview(" ".join(benign_check_texts)),
        )
        return False

    if stage == "input" and _is_benign_general_book_content(benign_check_texts):
        logger.info(
            "moderation_false_positive_ignored | stage=%s | preview=%s",
            stage,
            _safe_preview(" ".join(benign_check_texts)),
        )
        return False

    return True


def _create_streamed_response(client: Any, **kwargs: Any) -> Any:
    responses_api = getattr(client, "responses")
    stream_method = getattr(responses_api, "stream", None)

    if callable(stream_method):
        with stream_method(**kwargs) as stream:
            return stream.get_final_response()

    return responses_api.create(**kwargs)


def _build_moderation_block_result(
    validation: Any,
    response_language: str,
    *,
    tool_calls: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "status": "blocked_input",
        "blocked": True,
        "validation": validation.to_dict(),
        "matches": [],
        "tool_calls": tool_calls or [],
        "final_answer": CLASSIC_BLOCKED_MESSAGE,
        "response_language": response_language,
        "display": None,
    }


def _find_metadata_by_title(matches: list[dict[str, Any]], title: str) -> dict[str, Any]:
    normalized_title = title.strip().casefold()

    for match in matches:
        metadata = match.get("metadata") or {}
        candidate_title = str(metadata.get("title", "")).strip().casefold()

        if candidate_title == normalized_title:
            return metadata

    return {}


def _build_error_result(
    validation: Any,
    matches: list[dict[str, Any]],
    tool_calls: list[dict[str, Any]],
    message: str,
    response_language: str,
    display: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "status": "error",
        "blocked": False,
        "validation": validation.to_dict(),
        "matches": matches,
        "tool_calls": tool_calls,
        "final_answer": message,
        "response_language": response_language,
        "display": display,
    }


def _parse_tool_arguments(raw_arguments: Any) -> dict[str, Any]:
    if isinstance(raw_arguments, dict):
        return raw_arguments

    if not isinstance(raw_arguments, str):
        raise ValueError("argumentele tool-ului nu au formatul asteptat")

    parsed_arguments = json.loads(raw_arguments)
    if not isinstance(parsed_arguments, dict):
        raise ValueError("argumentele tool-ului trebuie sa fie un obiect JSON")

    return parsed_arguments


def _is_successful_tool_output(tool_output: str) -> bool:
    normalized = tool_output.strip().casefold()
    if normalized.startswith("eroare:"):
        return False
    if normalized.startswith("nu am gasit in baza locala"):
        return False
    return True


def _get_out_of_scope_message(language_code: str) -> str:
    if language_code == "en":
        return (
            "I can only help with questions about books, authors, titles, genres, "
            "themes, or recommendations from this catalog."
        )

    return (
        "Te pot ajuta doar cu intrebari despre carti, autori, titluri, genuri, "
        "teme sau recomandari din catalogul acestei aplicatii."
    )


def chat_once(user_query: str, n_results: int | None = None) -> dict[str, Any]:
    validation = validate_user_query(user_query)
    target_language = detect_user_language(validation.cleaned_text or user_query)
    target_language_name = get_language_name(target_language)

    if not validation.is_allowed:
        logger.info(
            "blocked_input | terms=%s | preview=%s",
            ",".join(validation.matched_terms or []),
            _safe_preview(validation.cleaned_text),
        )

        return {
            "status": "blocked_input",
            "blocked": True,
            "validation": validation.to_dict(),
            "matches": [],
            "tool_calls": [],
            "final_answer": validation.reason,
            "response_language": target_language,
            "display": None,
        }

    cleaned_query = validation.cleaned_text
    normalized_query = normalize_book_query_aliases(cleaned_query)
    if normalized_query != cleaned_query:
        logger.info(
            "normalized_book_query_alias | original=%s | normalized=%s",
            _safe_preview(cleaned_query),
            _safe_preview(normalized_query),
        )
        cleaned_query = normalized_query

    logger.info("accepted_input | preview=%s", _safe_preview(cleaned_query))

    if not is_book_related_query(cleaned_query):
        inferred_query = infer_book_query_from_preference(cleaned_query, target_language)
        if inferred_query:
            logger.info(
                "implicit_book_query | original=%s | rewritten=%s",
                _safe_preview(cleaned_query),
                _safe_preview(inferred_query),
            )
            cleaned_query = inferred_query
            target_language = detect_user_language(cleaned_query)
            target_language_name = get_language_name(target_language)
        else:
            logger.info("out_of_scope_input | preview=%s", _safe_preview(cleaned_query))
            return {
                "status": "out_of_scope",
                "blocked": False,
                "validation": validation.to_dict(),
                "matches": [],
                "tool_calls": [],
                "final_answer": _get_out_of_scope_message(target_language),
                "response_language": target_language,
                "display": None,
            }

    client = get_openai_client()

    if _is_moderation_flagged(client, [cleaned_query], stage="input"):
        logger.warning("input_moderation_blocked | preview=%s", _safe_preview(cleaned_query))
        return _build_moderation_block_result(validation, target_language)

    matches = search_books(cleaned_query, n_results=n_results or TOP_K)

    if not matches:
        logger.info("no_matches | preview=%s", _safe_preview(cleaned_query))
        return {
            "status": "no_matches",
            "blocked": False,
            "validation": validation.to_dict(),
            "matches": [],
            "tool_calls": [],
            "final_answer": "Nu am gasit nicio carte relevanta in catalogul disponibil.",
            "response_language": target_language,
            "display": None,
        }

    input_items: list[Any] = [
        {
            "role": "user",
            "content": build_rag_user_message(
                cleaned_query,
                matches,
                target_language_name,
            ),
        }
    ]

    result_payload: dict[str, Any] = {
        "status": "ok",
        "blocked": False,
        "validation": validation.to_dict(),
        "matches": matches,
        "tool_calls": [],
        "final_answer": "",
        "response_language": target_language,
        "display": {
            "recommended_title": None,
            "recommended_author": None,
            "genres": [],
            "why_this_book": "",
            "full_summary": "",
        },
    }

    allowed_titles = {
        str((match.get("metadata") or {}).get("title", "")).strip()
        for match in matches
        if str((match.get("metadata") or {}).get("title", "")).strip()
    }

    response = _create_streamed_response(
        client,
        model=LLM_MODEL,
        instructions=BOOK_RECOMMENDER_INSTRUCTIONS,
        input=input_items,
        tools=[GET_SUMMARY_BY_TITLE_TOOL],
        tool_choice="auto",
        parallel_tool_calls=False,
    )

    current_round = 0

    while current_round < MAX_TOOL_ROUNDS:
        function_calls = _extract_function_calls(response)

        if not function_calls:
            if not result_payload["tool_calls"]:
                logger.error("missing_required_tool_call | preview=%s", _safe_preview(cleaned_query))
                return _build_error_result(
                    validation,
                    matches,
                    [],
                    "Modelul nu a apelat tool-ul obligatoriu pentru rezumatul complet.",
                    target_language,
                )

            last_tool_call = result_payload["tool_calls"][-1]
            if not last_tool_call.get("ok", False):
                logger.error(
                    "tool_call_failed | name=%s | preview=%s",
                    last_tool_call.get("name"),
                    _safe_preview(cleaned_query),
                )
                return _build_error_result(
                    validation,
                    matches,
                    result_payload["tool_calls"],
                    "Nu am putut obtine rezumatul complet pentru recomandarea selectata.",
                    target_language,
                    result_payload["display"],
                )

            result_payload["final_answer"] = (
                getattr(response, "output_text", None) or "Modelul nu a returnat text."
            )
            result_payload["final_answer"] = normalize_text_to_target_language(
                client,
                result_payload["final_answer"],
                target_language,
            )
            result_payload["display"]["why_this_book"] = result_payload["final_answer"]

            if _is_moderation_flagged(
                client,
                [
                    result_payload["display"].get("full_summary", ""),
                    result_payload["final_answer"],
                ],
                stage="output",
                benign_context_texts=[cleaned_query],
            ):
                logger.warning("output_moderation_blocked | preview=%s", _safe_preview(cleaned_query))
                return _build_moderation_block_result(
                    validation,
                    target_language,
                    tool_calls=result_payload["tool_calls"],
                )

            logger.info(
                "completed | preview=%s",
                _safe_preview(result_payload["final_answer"]),
            )
            return result_payload

        if len(function_calls) > 1:
            logger.warning(
                "multiple_tool_calls_detected | count=%s | processing_first_only",
                len(function_calls),
            )
            function_calls = function_calls[:1]

        input_items.extend(getattr(response, "output", []) or [])
        tool_call = function_calls[0]

        try:
            parsed_arguments = _parse_tool_arguments(getattr(tool_call, "arguments", {}))
        except (json.JSONDecodeError, ValueError) as exc:
            parsed_arguments = {}
            selected_title = ""
            tool_output = f"Eroare: argumentele tool-ului nu sunt valide ({exc})."
            tool_ok = False
        else:
            requested_title = str(parsed_arguments.get("title", "")).strip()
            selected_title = resolve_catalog_title(requested_title, list(allowed_titles)) or ""

            if not requested_title:
                tool_output = "Eroare: tool-ul a fost apelat fara titlu."
                tool_ok = False
            elif not selected_title:
                tool_output = (
                    "Eroare: modelul a cerut un titlu care nu exista in candidatii returnati de retriever."
                )
                tool_ok = False
            else:
                parsed_arguments["title"] = selected_title
                try:
                    tool_output = execute_tool_call(tool_call.name, parsed_arguments)
                    tool_ok = _is_successful_tool_output(tool_output)
                    if tool_ok:
                        tool_output = normalize_text_to_target_language(
                            client,
                            tool_output,
                            target_language,
                        )
                except Exception as exc:
                    tool_output = f"Eroare la executia tool-ului {tool_call.name}: {exc}"
                    tool_ok = False

        logger.info(
            "tool_call | name=%s | arguments=%s",
            tool_call.name,
            parsed_arguments,
        )

        selected_metadata = _find_metadata_by_title(matches, selected_title)
        result_payload["tool_calls"].append(
            {
                "name": tool_call.name,
                "arguments": parsed_arguments,
                "output": tool_output,
                "ok": tool_ok,
            }
        )

        if selected_title:
            result_payload["display"]["recommended_title"] = selected_title
        if selected_metadata.get("author"):
            result_payload["display"]["recommended_author"] = selected_metadata.get("author")
        if selected_metadata.get("genres"):
            result_payload["display"]["genres"] = list(selected_metadata.get("genres") or [])

        result_payload["display"]["full_summary"] = tool_output

        input_items.append(
            {
                "type": "function_call_output",
                "call_id": tool_call.call_id,
                "output": tool_output,
            }
        )

        response = _create_streamed_response(
            client,
            model=LLM_MODEL,
            instructions=BOOK_RECOMMENDER_INSTRUCTIONS,
            input=input_items,
            tools=[GET_SUMMARY_BY_TITLE_TOOL],
            tool_choice="auto",
            parallel_tool_calls=False,
        )
        current_round += 1

    logger.error("tool_call_max_rounds_exceeded | preview=%s", _safe_preview(cleaned_query))
    return _build_error_result(
        validation,
        matches,
        result_payload["tool_calls"],
        "Modelul a depasit numarul maxim de iteratii de tool calling.",
        target_language,
        result_payload["display"],
    )
