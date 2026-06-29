defmodule RuleMaven.Repo.Migrations.AddPlayableToGames do
  use Ecto.Migration

  # Readiness flag for the catalog. `playable` is recomputed at the
  # application level (no backfill here). The catalog list filters on it
  # across a ~150k-row table, so it needs its own index.
  def change do
    alter table(:games) do
      add :playable, :boolean, null: false, default: false
      add :playable_at, :utc_datetime
    end

    create index(:games, [:playable])
  end
end
