defmodule RuleMaven.Repo.Migrations.CreateIngestLogs do
  use Ecto.Migration

  def change do
    create table(:ingest_logs) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :text, :string, null: false
      # info | page | warn | done | error — drives the line's icon/colour.
      add :kind, :string, null: false, default: "info"

      timestamps(updated_at: false)
    end

    # Read path: all lines for a game in insertion order.
    create index(:ingest_logs, [:game_id, :id])
  end
end
