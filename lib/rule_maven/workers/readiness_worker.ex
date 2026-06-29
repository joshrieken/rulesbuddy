defmodule RuleMaven.Workers.ReadinessWorker do
  @moduledoc """
  Durable driver for the one-click "Prepare game" pipeline (`RuleMaven.Readiness`).

  It owns no work of its own — it recomputes the game's readiness and kicks the
  next required step (cleanup → embed), or pauses at a human-gated step
  (review), or fans out enrichments once the game is playable. Each underlying
  step is its own durable Oban worker that, on finishing, calls
  `Readiness.advance/1` (from `Jobs.finish_run/3`) to re-enqueue this worker and
  walk the pipeline forward. Recomputing from persisted state every run makes the
  whole pipeline restart-safe.

  `unique` per game collapses the bursts of re-enqueues that happen when several
  steps finish close together.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      keys: [:game_id],
      states: [:available, :scheduled, :executing, :retryable, :suspended]
    ]

  alias RuleMaven.{Games, Readiness}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"game_id" => game_id}}) do
    case Games.get_game(game_id) do
      %Games.Game{} = game ->
        Readiness.recompute(game)
        if Readiness.auto?(game_id), do: Readiness.drive(game)
        :ok

      _ ->
        :ok
    end
  end
end
