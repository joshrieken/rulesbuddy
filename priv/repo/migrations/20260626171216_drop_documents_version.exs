defmodule RuleMaven.Repo.Migrations.DropDocumentsVersion do
  use Ecto.Migration

  # The documents.version column was never written or read (no real versioning).
  def change do
    alter table(:documents) do
      remove :version, :integer, default: 1, null: false
    end
  end
end
