defmodule RuleMaven.Repo.Migrations.CreateThemeEvents do
  use Ecto.Migration

  def change do
    create table(:theme_events) do
      # The theme slug (matches the data-theme value, e.g. "ocean", "matrix").
      add :theme, :string, null: false
      # Null for logged-out visitors.
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false)
    end

    # Aggregation reads group by theme; recent reads scan by time.
    create index(:theme_events, [:theme])
    create index(:theme_events, [:inserted_at])
  end
end
