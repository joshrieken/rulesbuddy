defmodule RuleMaven.UsersTest do
  use RuleMaven.DataCase

  alias RuleMaven.Users
  alias RuleMaven.Users.User
  alias RuleMaven.Repo

  describe "user management" do
    setup do
      {:ok, player} =
        Users.create_user(%{
          username: "player1",
          email: "player1@test.com",
          password: "testpass1234"
        })

      {:ok, gm} =
        Users.create_user(%{
          username: "gm1",
          email: "gm1@test.com",
          password: "testpass1234",
          role: "game_master"
        })

      %{player: player, gm: gm}
    end

    test "list_users/0 returns all users", %{player: player, gm: gm} do
      users = Users.list_users()
      ids = Enum.map(users, & &1.id)
      assert player.id in ids
      assert gm.id in ids
    end

    test "update_user/2 changes role", %{player: player} do
      {:ok, updated} = Users.update_user(player, %{role: "game_master"})
      assert updated.role == "game_master"
      assert Users.game_master?(updated)
    end

    test "update_user/2 rejects invalid role", %{player: player} do
      {:error, changeset} = Users.update_user(player, %{role: "super_admin"})
      assert changeset.errors[:role]
    end

    test "update_user/2 rejects duplicate username", %{player: player, gm: gm} do
      {:error, changeset} = Users.update_user(player, %{username: gm.username})
      assert changeset.errors[:username]
    end

    test "delete_user/1 removes the user", %{player: player} do
      {:ok, _} = Users.delete_user(player)
      assert Repo.get(User, player.id) == nil
    end

    test "delete_user/1 returns error for nil", %{} do
      assert {:error, :not_found} = Users.delete_user(nil)
    end

    test "update_user_role/2 is a convenience for role-only updates", %{player: player} do
      {:ok, updated} = Users.update_user_role(player, "game_master")
      assert updated.role == "game_master"
    end

    test "game_master?/1 returns true for game_master role", %{gm: gm} do
      assert Users.game_master?(gm)
    end

    test "game_master?/1 returns false for player role", %{player: player} do
      refute Users.game_master?(player)
    end
  end
end
