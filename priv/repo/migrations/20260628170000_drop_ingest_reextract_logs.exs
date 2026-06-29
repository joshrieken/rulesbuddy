defmodule RuleMaven.Repo.Migrations.DropIngestReextractLogs do
  use Ecto.Migration

  # The per-feature ingest/reextract progress logs are superseded by the unified
  # job log (job_runs/job_events). Drop the old tables.
  def up do
    drop_if_exists table(:ingest_logs)
    drop_if_exists table(:reextract_logs)
  end

  def down do
    create table(:ingest_logs) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :text, :string, null: false
      add :kind, :string, null: false, default: "info"
      timestamps(updated_at: false)
    end

    create index(:ingest_logs, [:game_id, :id])

    create table(:reextract_logs) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :text, :string, null: false
      add :kind, :string, null: false, default: "info"
      timestamps(updated_at: false)
    end

    create index(:reextract_logs, [:document_id, :id])
  end
end
