defmodule RuleMaven.Repo.Migrations.AddPdfPathToRulebookSources do
  use Ecto.Migration

  def change do
    alter table(:rulebook_sources) do
      add :pdf_path, :string
    end
  end
end
