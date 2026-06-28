defmodule RuleMaven.Repo.Migrations.AddUserSuspension do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # When set, the account is suspended: login is rejected and existing
      # sessions are denied at the auth boundaries (AuthPlug + UserLiveAuth).
      add :suspended_at, :utc_datetime
    end
  end
end
