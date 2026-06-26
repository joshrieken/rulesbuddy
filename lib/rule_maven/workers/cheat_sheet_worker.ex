defmodule RuleMaven.Workers.CheatSheetWorker do
  @moduledoc """
  Oban job: pre-generates a cheat sheet for a freshly created document and
  persists it as a `CheatSheetVersion` (the first version is marked active).

  Previously wrote to a non-existent `doc.cheatsheet` field, so the LLM result
  was silently discarded — this stores it where the app actually reads it.
  """

  use Oban.Worker, queue: :cheatsheet, max_attempts: 2

  alias RuleMaven.{Games, CheatSheet}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"document_id" => doc_id}}) do
    doc = Games.get_document!(doc_id)
    game = Games.get_game!(doc.game_id)

    case CheatSheet.generate_content(game) do
      {:ok, content} ->
        CheatSheet.save_version(doc_id, content)
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
