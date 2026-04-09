import json
import sys
from types import SimpleNamespace

sys.modules.setdefault(
    "chromadb",
    SimpleNamespace(PersistentClient=lambda *args, **kwargs: None),
)

from src.chatbot import chat_once


class DummyResponsesApi:
    def __init__(self, responses):
        self._responses = list(responses)

    def create(self, **kwargs):
        if not self._responses:
            raise AssertionError("No more dummy responses configured.")
        return self._responses.pop(0)


class DummyModerationsApi:
    def __init__(self, flags):
        self._flags = list(flags)

    def create(self, **kwargs):
        if not self._flags:
            raise AssertionError("No more moderation responses configured.")
        return SimpleNamespace(
            results=[SimpleNamespace(flagged=self._flags.pop(0))]
        )


class DummyClient:
    def __init__(self, responses, moderation_flags=None):
        self.responses = DummyResponsesApi(responses)
        if moderation_flags is not None:
            self.moderations = DummyModerationsApi(moderation_flags)


def _match(title: str, author: str = "George Orwell") -> dict:
    return {
        "id": f"book_{title.lower().replace(' ', '_')}",
        "document": f"Title: {title}",
        "distance": 0.1,
        "metadata": {
            "title": title,
            "author": author,
            "genres": ["science fiction"],
            "themes": ["freedom"],
            "tone": ["serious"],
            "audience": "adult",
            "language": "en",
            "short_summary": f"Short summary for {title}.",
        },
    }


def test_chat_once_completes_tool_flow(monkeypatch):
    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("1984")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "1984"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand 1984 de George Orwell pentru tema libertatii.",
                ),
            ]
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru 1984.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("Vreau o carte despre libertate.")

    assert result["status"] == "ok"
    assert result["response_language"] == "ro"
    assert result["tool_calls"][0]["name"] == "get_summary_by_title"
    assert result["tool_calls"][0]["ok"] is True
    assert result["display"]["recommended_title"] == "1984"
    assert result["display"]["recommended_author"] == "George Orwell"
    assert result["display"]["genres"] == ["science fiction"]
    assert result["display"]["full_summary"] == "Rezumat complet pentru 1984."
    assert "George Orwell" in result["final_answer"]


def test_chat_once_returns_error_when_model_skips_required_tool(monkeypatch):
    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("1984")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand 1984.",
                )
            ]
        ),
    )

    result = chat_once("Ce este 1984?")

    assert result["status"] == "error"
    assert result["response_language"] == "ro"
    assert result["tool_calls"] == []
    assert "tool-ul obligatoriu" in result["final_answer"]


def test_chat_once_returns_error_for_title_outside_retrieved_candidates(monkeypatch):
    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("1984")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "Super Sikh"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand Super Sikh.",
                ),
            ]
        ),
    )

    result = chat_once("Da-mi o carte SF")

    assert result["status"] == "error"
    assert result["response_language"] == "ro"
    assert result["tool_calls"][0]["ok"] is False
    assert "titlu care nu exista" in result["tool_calls"][0]["output"]


def test_chat_once_accepts_tool_title_without_subtitle_when_unique(monkeypatch):
    captured_arguments = {}

    monkeypatch.setattr(
        "src.chatbot.search_books",
        lambda *args, **kwargs: [_match("The Viscount Who Loved Me: Bridgerton", author="Julia Quinn")],
    )
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "The Viscount Who Loved Me"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="I recommend The Viscount Who Loved Me: Bridgerton by Julia Quinn.",
                ),
            ]
        ),
    )

    def _capture_execute_tool_call(tool_name, arguments):
        captured_arguments["tool_name"] = tool_name
        captured_arguments["arguments"] = dict(arguments)
        return "A romance with tension and chemistry."

    monkeypatch.setattr("src.chatbot.execute_tool_call", _capture_execute_tool_call)
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("I love books with action and romance.")

    assert result["status"] == "ok"
    assert result["tool_calls"][0]["ok"] is True
    assert captured_arguments["arguments"]["title"] == "The Viscount Who Loved Me: Bridgerton"
    assert result["display"]["recommended_title"] == "The Viscount Who Loved Me: Bridgerton"


def test_chat_once_accepts_tool_title_with_author_suffix(monkeypatch):
    captured_arguments = {}

    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("Pride and Prejudice", author="Jane Austen")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "Pride and Prejudice by Jane Austen"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="I recommend Pride and Prejudice by Jane Austen.",
                ),
            ]
        ),
    )

    def _capture_execute_tool_call(tool_name, arguments):
        captured_arguments["tool_name"] = tool_name
        captured_arguments["arguments"] = dict(arguments)
        return "A classic romance."

    monkeypatch.setattr("src.chatbot.execute_tool_call", _capture_execute_tool_call)
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("I want a romance classic.")

    assert result["status"] == "ok"
    assert result["tool_calls"][0]["ok"] is True
    assert captured_arguments["arguments"]["title"] == "Pride and Prejudice"
    assert result["display"]["recommended_title"] == "Pride and Prejudice"


def test_chat_once_blocks_offensive_input_before_retrieval_and_llm(monkeypatch):
    def _should_not_run(*args, **kwargs):
        raise AssertionError("This function should not be called for blocked input.")

    monkeypatch.setattr("src.chatbot.search_books", _should_not_run)
    monkeypatch.setattr("src.chatbot.get_openai_client", _should_not_run)

    result = chat_once("You are stupid")

    assert result["status"] == "blocked_input"
    assert result["blocked"] is True
    assert "fara limbaj ofensator" in result["final_answer"].lower()
    assert "stupid" in result["validation"]["matched_terms"]


def test_chat_once_rejects_out_of_scope_input_before_retrieval_and_llm(monkeypatch):
    def _should_not_run(*args, **kwargs):
        raise AssertionError("This function should not be called for out-of-scope input.")

    monkeypatch.setattr("src.chatbot.search_books", _should_not_run)
    monkeypatch.setattr("src.chatbot.get_openai_client", _should_not_run)

    result = chat_once("Cum va fi vremea maine?")

    assert result["status"] == "out_of_scope"
    assert result["blocked"] is False
    assert "doar cu intrebari despre carti" in result["final_answer"].lower()


def test_chat_once_blocks_flagged_input_via_openai_moderation(monkeypatch):
    def _should_not_run(*args, **kwargs):
        raise AssertionError("This function should not be called for moderated input.")

    monkeypatch.setattr("src.chatbot.search_books", _should_not_run)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient([], moderation_flags=[True]),
    )

    result = chat_once("Vreau o carte cu violenta extrema.")

    assert result["status"] == "blocked_input"
    assert result["blocked"] is True
    assert "fara limbaj ofensator" in result["final_answer"].lower()


def test_chat_once_ignores_false_positive_moderation_for_children_books(monkeypatch):
    captured_queries = []

    def _search_books(query, **kwargs):
        captured_queries.append(query)
        return [_match("The Hobbit", author="J.R.R. Tolkien")]

    monkeypatch.setattr("src.chatbot.search_books", _search_books)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "The Hobbit"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand The Hobbit.",
                ),
            ],
            moderation_flags=[True, False],
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru The Hobbit.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("Vreau o carte pentru copii")

    assert result["status"] == "ok"
    assert captured_queries == ["Vreau o carte pentru copii"]


def test_chat_once_ignores_false_positive_moderation_for_benign_book_topic(monkeypatch):
    captured_queries = []

    def _search_books(query, **kwargs):
        captured_queries.append(query)
        return [_match("Cars", author="Auto Author")]

    monkeypatch.setattr("src.chatbot.search_books", _search_books)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "Cars"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand Cars.",
                ),
            ],
            moderation_flags=[True, False],
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru Cars.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("Vreau o carte cu masini")

    assert result["status"] == "ok"
    assert captured_queries == ["Vreau o carte cu masini"]


def test_chat_once_accepts_preference_fragment_as_book_topic(monkeypatch):
    captured_queries = []

    def _search_books(query, **kwargs):
        captured_queries.append(query)
        return [_match("1984")]

    monkeypatch.setattr("src.chatbot.search_books", _search_books)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "1984"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand 1984.",
                ),
            ]
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru 1984.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("imi place pompierii")

    assert result["status"] == "ok"
    assert captured_queries == ["Vreau o carte despre pompierii."]


def test_chat_once_accepts_ador_preference_fragment_as_book_topic(monkeypatch):
    captured_queries = []

    def _search_books(query, **kwargs):
        captured_queries.append(query)
        return [_match("1984")]

    monkeypatch.setattr("src.chatbot.search_books", _search_books)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "1984"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand 1984.",
                ),
            ]
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru 1984.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("ador pompierii")

    assert result["status"] == "ok"
    assert result["response_language"] == "ro"
    assert captured_queries == ["Vreau o carte despre pompierii."]


def test_chat_once_blocks_flagged_output_via_openai_moderation(monkeypatch):
    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("1984")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "1984"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand 1984 de George Orwell.",
                ),
            ],
            moderation_flags=[False, True],
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru 1984.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("Vreau o carte despre libertate.")

    assert result["status"] == "blocked_input"
    assert result["blocked"] is True
    assert "fara limbaj ofensator" in result["final_answer"].lower()


def test_chat_once_ignores_false_positive_output_moderation_for_children_books(monkeypatch):
    monkeypatch.setattr(
        "src.chatbot.search_books",
        lambda *args, **kwargs: [_match("The Hobbit", author="J.R.R. Tolkien")],
    )
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "The Hobbit"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand The Hobbit pentru cititori tineri.",
                ),
            ],
            moderation_flags=[False, True],
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru The Hobbit.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("Vreau o carte pentru copii")

    assert result["status"] == "ok"
    assert result["display"]["recommended_title"] == "The Hobbit"


def test_chat_once_normalizes_mystery_typo_before_retrieval(monkeypatch):
    captured_queries = []

    def _search_books(query, **kwargs):
        captured_queries.append(query)
        return [_match("The Hound of the Baskervilles", author="Arthur Conan Doyle")]

    monkeypatch.setattr("src.chatbot.search_books", _search_books)
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "The Hound of the Baskervilles"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="Iti recomand The Hound of the Baskervilles.",
                ),
            ]
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "Rezumat complet pentru The Hound of the Baskervilles.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: text,
    )

    result = chat_once("vreau ceva cu mistery")

    assert result["status"] == "ok"
    assert captured_queries == ["vreau ceva cu mystery"]


def test_chat_once_translates_summary_and_final_answer_to_user_language(monkeypatch):
    monkeypatch.setattr("src.chatbot.search_books", lambda *args, **kwargs: [_match("1984")])
    monkeypatch.setattr(
        "src.chatbot.get_openai_client",
        lambda: DummyClient(
            [
                SimpleNamespace(
                    output=[
                        SimpleNamespace(
                            type="function_call",
                            name="get_summary_by_title",
                            arguments=json.dumps({"title": "1984"}),
                            call_id="call_1",
                        )
                    ],
                    output_text="",
                ),
                SimpleNamespace(
                    output=[],
                    output_text="I recommend 1984 by George Orwell.",
                ),
            ]
        ),
    )
    monkeypatch.setattr(
        "src.chatbot.execute_tool_call",
        lambda tool_name, arguments: "A bleak dystopian novel.",
    )
    monkeypatch.setattr(
        "src.chatbot.normalize_text_to_target_language",
        lambda client, text, target_language: f"[{target_language}] {text}",
    )

    result = chat_once("Vreau o carte despre libertate si control social.")

    assert result["status"] == "ok"
    assert result["response_language"] == "ro"
    assert result["display"]["full_summary"] == "[ro] A bleak dystopian novel."
    assert result["final_answer"] == "[ro] I recommend 1984 by George Orwell."
