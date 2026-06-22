defmodule RuleMaven.Repo.Migrations.AddReferencesSectionToChunks do
  use Ecto.Migration

  def change do
    alter table(:chunks) do
      add :references_section, {:array, :text}, default: []
    end
  end
end
