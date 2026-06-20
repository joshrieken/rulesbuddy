defmodule RuleMaven.Repo.Migrations.CreateLlmLogs do
  use Ecto.Migration

  def change do
    create table(:llm_logs) do
      add :provider, :string, null: false
      add :model, :string, null: false
      add :operation, :string, null: false
      add :prompt_tokens, :integer
      add :completion_tokens, :integer
      add :total_tokens, :integer
      add :duration_ms, :integer
      add :success, :boolean, default: true
      add :error_message, :string
      add :game_id, references(:games, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:llm_logs, [:inserted_at])
    create index(:llm_logs, [:provider])
    create index(:llm_logs, [:operation])
  end
end
