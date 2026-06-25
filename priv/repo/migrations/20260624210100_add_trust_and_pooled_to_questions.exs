defmodule RuleMaven.Repo.Migrations.AddTrustAndPooledToQuestions do
  use Ecto.Migration

  def up do
    alter table(:questions_log) do
      add :trust_score, :float, null: false, default: 0.0
      add :pooled, :boolean, null: false, default: false
      # When this row was served from the cache pool, points at the source
      # (canonical/provisional) row so votes on the served answer accrue there.
      add :pool_source_id, references(:questions_log, on_delete: :nilify_all)
    end

    # Backfill: existing community-promoted rows are already cache-eligible.
    execute "UPDATE questions_log SET pooled = true WHERE visibility = 'community'"

    create index(:questions_log, [:game_id, :pooled])
  end

  def down do
    drop index(:questions_log, [:game_id, :pooled])

    alter table(:questions_log) do
      remove :trust_score
      remove :pooled
      remove :pool_source_id
    end
  end
end
