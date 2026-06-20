defmodule RuleMaven.Repo.Migrations.CreateRulebookSources do
  use Ecto.Migration

  def change do
    create table(:rulebook_sources) do
      add :label, :string
      add :full_text, :text
      add :game_id, references(:games, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:rulebook_sources, [:game_id])
  end
end
