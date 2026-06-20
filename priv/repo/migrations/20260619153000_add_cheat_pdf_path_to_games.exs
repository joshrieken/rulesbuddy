defmodule RuleMaven.Repo.Migrations.AddCheatPdfPathToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :cheat_pdf_path, :string
    end
  end
end
