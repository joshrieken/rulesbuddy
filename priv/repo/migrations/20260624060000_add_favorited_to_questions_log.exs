defmodule RuleMaven.Repo.Migrations.AddFavoritedToQuestionsLog do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      add :favorited, :boolean, default: false, null: false
    end

    create index(:questions_log, [:favorited])
  end
end
