defmodule RuleMaven.Repo.Migrations.AddCategoryToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :category, :string, default: "board_game", null: false
    end
  end
end
