defmodule RuleMaven.Repo.Migrations.AddIsCoreToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :is_core, :boolean, default: false, null: false
    end
  end
end
