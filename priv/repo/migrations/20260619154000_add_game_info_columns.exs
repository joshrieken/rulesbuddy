defmodule RuleMaven.Repo.Migrations.AddGameInfoColumns do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :year_published, :integer
      add :min_players, :integer
      add :max_players, :integer
      add :playing_time, :integer
      add :image_url, :string
    end
  end
end
