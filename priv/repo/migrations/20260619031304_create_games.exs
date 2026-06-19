defmodule RulesBuddy.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :name, :string
      add :bgg_id, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
