defmodule RuleMaven.Repo.Migrations.AddNeedsReviewToQuestionsLog do
  use Ecto.Migration

  def change do
    # Flag set when a rulebook content change may have made a community-shared
    # answer stale. Flagged answers are skipped by the pool lookup (so they stop
    # serving) until a moderator re-approves them — instead of silently dropping
    # or regenerating curated answers.
    alter table(:questions_log) do
      add :needs_review, :boolean, default: false, null: false
    end

    create index(:questions_log, [:needs_review])
  end
end
