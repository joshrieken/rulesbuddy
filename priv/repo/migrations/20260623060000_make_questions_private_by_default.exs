defmodule RuleMaven.Repo.Migrations.MakeQuestionsPrivateByDefault do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      modify :visibility, :string, default: "private", null: false
    end

    execute(
      "UPDATE questions_log SET visibility = 'private' WHERE visibility IS NULL",
      "SELECT 1"
    )
  end
end
