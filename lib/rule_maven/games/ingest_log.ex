defmodule RuleMaven.Games.IngestLog do
  @moduledoc """
  One line of an extraction progress log for a game's incoming document. Rows are
  append-only (one INSERT per event), so the parallel per-page extraction tasks
  can write concurrently with no read-modify-write race. Durable (Postgres) so the
  log survives a browser refresh and an Oban/server restart; cleared at the start
  of each ingest run.
  """
  use Ecto.Schema

  schema "ingest_logs" do
    field :text, :string
    field :kind, :string, default: "info"
    belongs_to :game, RuleMaven.Games.Game

    timestamps(updated_at: false)
  end
end
