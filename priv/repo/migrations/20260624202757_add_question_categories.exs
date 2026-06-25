defmodule RuleMaven.Repo.Migrations.AddQuestionCategories do
  use Ecto.Migration

  def change do
    create table(:game_categories) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :string
      add :name_embedding, :vector, size: 768
      timestamps()
    end

    create index(:game_categories, [:game_id])

    create table(:question_category_tags) do
      add :question_log_id, references(:questions_log, on_delete: :delete_all), null: false
      add :game_category_id, references(:game_categories, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:question_category_tags, [:question_log_id, :game_category_id])
    create index(:question_category_tags, [:game_category_id])
  end
end
