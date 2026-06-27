defmodule RuleMaven.Repo.Migrations.AddCleaningDoneToDocuments do
  use Ecto.Migration

  def change do
    # Durable per-run cleanup progress: pages persisted so far this run. nil when
    # no cleanup is in flight. Drives a reliable counter that survives refreshes.
    alter table(:documents) do
      add :cleaning_done, :integer
    end
  end
end
