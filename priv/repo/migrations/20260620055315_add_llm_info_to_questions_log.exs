defmodule RuleMaven.Repo.Migrations.AddLlmInfoToQuestionsLog do
  use Ecto.Migration

  def change do
    alter table(:questions_log) do
      add :llm_provider, :string
      add :llm_model, :string
    end
  end
end
