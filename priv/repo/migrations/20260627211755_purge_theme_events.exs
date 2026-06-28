defmodule RuleMaven.Repo.Migrations.PurgeThemeEvents do
  use Ecto.Migration

  # Theme slugs were standardized (e.g. "ocean" -> "abyss", "dark" -> "midnight"),
  # so historical theme_events rows are keyed by names that no longer exist.
  # Wipe the analytics history; tracking continues fresh under the new slugs.
  def up do
    execute("DELETE FROM theme_events")
  end

  def down do
    :ok
  end
end
