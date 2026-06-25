defmodule RuleMaven.Repo.Migrations.AddWeightToQuestionVotes do
  use Ecto.Migration

  def change do
    alter table(:question_votes) do
      # Snapshot of the voter's vote weight at cast time, so trust recompute
      # is a cheap sum and historical votes don't shift as reputation changes.
      add :weight, :float, null: false, default: 1.0
    end
  end
end
