from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.table import Table

from src.chatbot import chat_once
from src.config import DATA_FILE
from src.data_loader import load_books
from src.vector_store import get_collection_size, rebuild_vector_store

console = Console()


def print_retrieval_matches(matches: list[dict]) -> None:
    if not matches:
        console.print("[bold red]Retriever-ul nu a gasit rezultate.[/bold red]")
        return

    table = Table(title="Rezultate din retriever (ChromaDB)")
    table.add_column("#", style="cyan", no_wrap=True)
    table.add_column("Titlu", style="bold")
    table.add_column("Autor")
    table.add_column("Distance")
    table.add_column("Themes")

    for index, match in enumerate(matches, start=1):
        metadata = match.get("metadata") or {}
        distance = match.get("distance")

        if isinstance(distance, (float, int)):
            distance_text = f"{distance:.4f}"
        else:
            distance_text = "-"

        themes = ", ".join(metadata.get("themes", []))

        table.add_row(
            str(index),
            metadata.get("title", "-"),
            metadata.get("author", "-"),
            distance_text,
            themes,
        )

    console.print(table)


def print_tool_calls(tool_calls: list[dict]) -> None:
    if not tool_calls:
        console.print("[yellow]Modelul nu a facut niciun tool call.[/yellow]")
        return

    for index, tool_call in enumerate(tool_calls, start=1):
        content = (
            f"[bold]Tool name:[/bold] {tool_call['name']}\n"
            f"[bold]Arguments:[/bold] {tool_call['arguments']}\n"
            f"[bold]Tool output:[/bold] {tool_call['output']}"
        )

        console.print(
            Panel(
                content,
                title=f"Tool call #{index}",
                border_style="magenta",
            )
        )


def main() -> None:
    console.print("[bold cyan]Smart Librarian CLI[/bold cyan]\n")

    books = load_books(DATA_FILE)
    console.print(f"Am incarcat {len(books)} carti din JSON.")

    current_count = get_collection_size()
    if current_count != len(books):
        current_count = rebuild_vector_store(books)
        console.print(f"Vector store reconstruit. Inregistrari salvate: {current_count}")
    else:
        console.print(f"Vector store deja sincronizat. Inregistrari salvate: {current_count}")

    console.print(f"Verificare count() din colectie: {get_collection_size()}")

    console.print("\nScrie [bold]exit[/bold] ca sa iesi.\n")

    while True:
        user_query = Prompt.ask("[bold green]Intrebarea ta[/bold green]").strip()

        if user_query.lower() in {"exit", "quit"}:
            console.print("[bold]La revedere![/bold]")
            break

        try:
            result = chat_once(user_query)
        except Exception as exc:
            console.print(f"[bold red]A aparut o eroare:[/bold red] {exc}\n")
            continue

        if result["status"] == "blocked_input":
            console.print()
            console.print(
                Panel(
                    result["final_answer"],
                    title="Mesaj blocat local",
                    border_style="red",
                )
            )
            console.print(
                "[italic]Nu am trimis acest mesaj nici la embeddings, nici la LLM.[/italic]\n"
            )
            continue

        console.print()

        if result["matches"]:
            print_retrieval_matches(result["matches"])
            console.print()

        if result["tool_calls"]:
            print_tool_calls(result["tool_calls"])
            console.print()

        console.print(
            Panel(
                result["final_answer"],
                title="Raspuns final al chatbotului",
                border_style="blue",
            )
        )
        console.print()


if __name__ == "__main__":
    main()
