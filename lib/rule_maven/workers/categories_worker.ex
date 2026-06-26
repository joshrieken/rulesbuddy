defmodule RuleMaven.Workers.CategoriesWorker do
  @moduledoc """
  Durable generation of suggested game categories. Persists to
  `categories_<game_id>` and broadcasts `{:categories_ready, cats}` on `topic/1`.
  Replaces a detached `Task.start`.
  """
  use Oban.Worker,
    queue: :llm,
    max_attempts: 3,
    unique: [keys: [:game_id], states: [:available, :scheduled, :executing, :retryable, :suspended]]

  alias RuleMaven.{Games, Settings}

  def topic(game_id), do: "categories:#{game_id}"

  @doc "Enqueue category generation (no-op in test where Oban isn't supervised)."
  def enqueue(game_id) do
    if oban_running?() do
      %{game_id: game_id} |> new() |> Oban.insert()
    else
      :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"game_id" => game_id}}) do
    game = Games.get_game!(game_id)
    text = Games.document_full_text(game)

    cats =
      case RuleMaven.LLM.generate_categories(game.name, text) do
        {:ok, cats} ->
          Settings.put("categories_#{game_id}", Jason.encode!(cats))
          cats

        {:error, _} ->
          []
      end

    Phoenix.PubSub.broadcast(RuleMaven.PubSub, topic(game_id), {:categories_ready, cats})
    :ok
  end

  defp oban_running?, do: Application.get_env(:rule_maven, Oban)[:testing] != :manual
end
