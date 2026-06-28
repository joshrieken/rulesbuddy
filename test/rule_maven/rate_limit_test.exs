defmodule RuleMaven.RateLimitTest do
  use RuleMaven.DataCase

  import RuleMaven.GamesFixtures

  alias RuleMaven.{Games, Users}

  defp user_fixture(name, attrs \\ %{}) do
    {:ok, u} =
      Users.create_user(
        Map.merge(
          %{username: name, email: "#{name}@test.com", password: "testpass1234"},
          attrs
        )
      )

    u
  end

  defp ask(game, user, attrs) do
    {:ok, q} =
      Games.log_question(
        Map.merge(
          %{game_id: game.id, question: "q?", answer: "a", user_id: user.id},
          attrs
        )
      )

    q
  end

  setup do
    %{game: game_fixture()}
  end

  test "fresh asks count toward the per-user monthly quota", %{game: game} do
    user = user_fixture("limited")
    {:ok, user} = Users.set_quota(user, 2)

    ask(game, user, %{})
    assert Games.check_rate_limit(user) == :ok

    ask(game, user, %{})
    assert {:error, msg} = Games.check_rate_limit(user)
    assert msg =~ "quota"
  end

  test "cache/pool hits do NOT count toward the quota", %{game: game} do
    user = user_fixture("cached")
    {:ok, user} = Users.set_quota(user, 1)
    # A real source row (authored by someone else) for the cache hits to point at.
    source = ask(game, user_fixture("author"), %{})

    # A pile of cache hits (pool_source_id set) stays well under quota.
    for _ <- 1..10, do: ask(game, user, %{pool_source_id: source.id})
    assert Games.check_rate_limit(user) == :ok

    # The first *fresh* generation hits the quota of 1.
    ask(game, user, %{})
    assert {:error, _} = Games.check_rate_limit(user)
  end

  test "admins are exempt from quotas", %{game: game} do
    admin = user_fixture("boss", %{role: "admin"})
    {:ok, admin} = Users.set_quota(admin, 1)

    for _ <- 1..5, do: ask(game, admin, %{})
    assert Games.check_rate_limit(admin) == :ok
  end

  test "raising a user's quota lets them ask again", %{game: game} do
    user = user_fixture("topped")
    {:ok, user} = Users.set_quota(user, 1)
    ask(game, user, %{})
    assert {:error, _} = Games.check_rate_limit(user)

    {:ok, user} = Users.set_quota(user, 50)
    assert Games.check_rate_limit(user) == :ok
  end
end
