defmodule RuleMaven.Repo.Migrations.CreateQuestionsLog do
  use Ecto.Migration

  def change do
    create table(:questions_log) do
      add :question, :text
      add :answer, :text
      add :cited_passage, :text
      add :game_id, references(:games, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:questions_log, [:game_id])
  end
end
