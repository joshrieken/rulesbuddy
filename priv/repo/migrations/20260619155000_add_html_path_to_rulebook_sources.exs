defmodule RuleMaven.Repo.Migrations.AddHtmlPathToRulebookSources do
  use Ecto.Migration

  def change do
    alter table(:rulebook_sources) do
      add :html_path, :string
    end
  end
end
