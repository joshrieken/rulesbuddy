defmodule RuleMaven.Repo.Migrations.AddReputationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reputation, :integer, null: false, default: 0
    end
  end
end
