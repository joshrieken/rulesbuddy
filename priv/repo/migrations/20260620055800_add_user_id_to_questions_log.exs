defmodule RuleMaven.Repo.Migrations.AddUserIdToQuestionsLog do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      add :user_id, references(:users, on_delete: :nothing), null: true
    end
  end
end
