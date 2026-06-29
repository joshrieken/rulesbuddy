defmodule RuleMaven.Repo.Migrations.CreateGameVoices do
  use Ecto.Migration

  def change do
    create table(:game_voices) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :label, :string, null: false
      add :emoji, :string, null: false
      add :style, :text, null: false
      add :source, :string, null: false, default: "generated"
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    # One row per (game, slug); the resolver namespaces these as `g:<slug>` so a
    # generated voice can never collide with a built-in global voice id.
    create unique_index(:game_voices, [:game_id, :slug])
    create index(:game_voices, [:game_id])
  end
end
