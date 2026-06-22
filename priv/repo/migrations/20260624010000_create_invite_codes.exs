defmodule RuleMaven.Repo.Migrations.CreateInviteCodes do
  use Ecto.Migration

  def change do
    create table(:invite_codes) do
      add :code, :string, null: false
      add :max_uses, :integer, default: 1, null: false
      add :use_count, :integer, default: 0, null: false
      add :active, :boolean, default: true, null: false
      add :expires_at, :utc_datetime
      add :created_by_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invite_codes, [:code])
    create index(:invite_codes, [:created_by_id])
  end
end
