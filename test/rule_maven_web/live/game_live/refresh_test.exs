defmodule RuleMavenWeb.GameLive.RefreshTest do
  use RuleMavenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RuleMaven.GamesFixtures

  setup %{conn: conn} do
    {:ok, user} =
      RuleMaven.Users.create_user(%{
        username: "gm_refresh_test",
        email: "gm_refresh@test.com",
        password: "password123456",
        role: "game_master"
      })

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    {:ok, conn: conn, user: user}
  end

  test "renders no-games message when no games with bgg_id", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/games/refresh")
    assert render(view) =~ "No games with BGG IDs to refresh"
  end

  test "shows progress bar and game name", %{conn: conn} do
    game_fixture(%{name: "RefreshTestGame", bgg_id: 99_999})

    {:ok, view, _html} = live(conn, "/games/refresh")
    html = render(view)

    assert html =~ "RefreshTestGame"
    assert html =~ "%"
  end
end
