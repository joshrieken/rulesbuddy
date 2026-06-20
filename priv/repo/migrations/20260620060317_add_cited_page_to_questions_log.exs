defmodule RuleMaven.Repo.Migrations.AddCitedPageToQuestionsLog do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      add :cited_page, :integer, null: true
    end
  end
end
