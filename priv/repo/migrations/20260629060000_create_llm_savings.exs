defmodule RuleMaven.Repo.Migrations.CreateLlmSavings do
  use Ecto.Migration

  def change do
    create table(:llm_savings) do
      add :kind, :string, null: false
      add :operation, :string
      add :estimated_tokens, :integer, default: 0
      add :estimated_usd, :float, default: 0.0
      add :model, :string
      add :game_id, references(:games, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:llm_savings, [:inserted_at])
    create index(:llm_savings, [:kind, :inserted_at])
  end
end
