defmodule RuleMaven.Repo.Migrations.CreateAppSettings do
  use Ecto.Migration

  def change do
    create table(:app_settings, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :text

      timestamps(type: :utc_datetime)
    end
  end
end
