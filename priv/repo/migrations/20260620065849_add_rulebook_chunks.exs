defmodule RuleMaven.Repo.Migrations.AddRulebookChunks do
  use Ecto.Migration

  def change do
    create table(:rulebook_chunks) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :source_id, references(:rulebook_sources, on_delete: :delete_all), null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rulebook_chunks, [:game_id])
  end
end
