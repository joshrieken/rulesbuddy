defmodule RuleMaven.Repo.Migrations.CreateGameSupportRequests do
  use Ecto.Migration

  # Tracks user requests to support (add a rulebook for) a game that's in their
  # collection but not yet playable. One row per user/game (deduped).
  def change do
    create table(:game_support_requests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_support_requests, [:user_id, :game_id])
    create index(:game_support_requests, [:game_id])
  end
end
