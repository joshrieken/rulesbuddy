defmodule RuleMaven.Repo.Migrations.AddSourceUrlToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :source_url, :string
    end
  end
end
