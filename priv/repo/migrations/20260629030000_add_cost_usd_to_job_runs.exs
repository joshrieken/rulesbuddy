defmodule RuleMaven.Repo.Migrations.AddCostUsdToJobRuns do
  use Ecto.Migration

  # Per-run LLM/processing cost, populated by workers as they finish.
  def change do
    alter table(:job_runs) do
      add :cost_usd, :float
    end
  end
end
