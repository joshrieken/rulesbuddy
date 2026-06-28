defmodule RuleMaven.Repo.Migrations.RenamePlayerRoleToUser do
  use Ecto.Migration

  # The "player" role was renamed to "user"; migrate any existing rows.
  def up do
    execute("UPDATE users SET role = 'user' WHERE role = 'player'")
  end

  def down do
    execute("UPDATE users SET role = 'player' WHERE role = 'user'")
  end
end
