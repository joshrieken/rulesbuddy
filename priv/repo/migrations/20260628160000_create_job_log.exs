defmodule RuleMaven.Repo.Migrations.CreateJobLog do
  use Ecto.Migration

  def change do
    create table(:job_runs) do
      # Worker family, e.g. "download" | "cleanup" | "reextract" | "cheat_sheet"
      # | "suggestions" | "theme_palette" | "embed" | "voice" | "did_you_know"
      # | "categories" | "expansion_sync" | "bgg_enrich" | "ask" | "tag"
      # | "setup_checklist" | "direct_promotion".
      add :kind, :string, null: false
      # What the run is about, so the panel can group/filter and deep-link.
      add :scope_type, :string, null: false, default: "global"
      add :scope_id, :integer
      # Human title for the left rail (game/source/question name).
      add :label, :string
      # running | done | failed
      add :state, :string, null: false, default: "running"
      # Short terminal outcome line.
      add :summary, :string
      # Soft link to the backing Oban job for cross-reference (nullable).
      add :oban_job_id, :integer
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec

      timestamps()
    end

    create index(:job_runs, [:state])
    create index(:job_runs, [:kind])
    create index(:job_runs, [:scope_type, :scope_id])
    # Left-rail order + the retention prune both scan by recency.
    create index(:job_runs, [:inserted_at])

    create table(:job_events) do
      add :job_run_id, references(:job_runs, on_delete: :delete_all), null: false
      # info | warn | error | done — drives the line colour (shared vocabulary
      # with the old ingest/reextract logs this replaces).
      add :level, :string, null: false, default: "info"
      add :message, :string, null: false
      # Optional structured payload (page index, counts, etc).
      add :meta, :map, null: false, default: %{}

      timestamps(updated_at: false)
    end

    # Read path: a run's event stream in insertion order.
    create index(:job_events, [:job_run_id, :id])
    # Retention prune scans by age.
    create index(:job_events, [:inserted_at])
  end
end
