defmodule RuleMaven.Repo.Migrations.AddPinnedToQuestionsLog do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      add :pinned, :boolean, default: false
    end
  end
end
