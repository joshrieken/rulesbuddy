defmodule RuleMaven.Repo.Migrations.CreateUserFavorites do
  use Ecto.Migration

  # Per-user favorites overlay on the global catalog.
  def change do
    create table(:user_favorites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_favorites, [:user_id, :game_id])
    create index(:user_favorites, [:game_id])
  end
end
