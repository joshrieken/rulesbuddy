defmodule RuleMaven.Repo.Migrations.AddMonthlyQuotaToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :monthly_quota, :integer, null: false, default: 200
    end
  end
end
