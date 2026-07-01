defmodule RuleMavenWeb.PrepareRenderTest do
  use RuleMavenWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import RuleMaven.GamesFixtures

  test "prepare page renders for a saved-but-unextracted source", %{conn: conn} do
    {:ok, admin} =
      RuleMaven.Users.create_user(%{
        username: "prep_render_admin",
        email: "pra@test.com",
        password: "password1234",
        role: "admin"
      })

    game = game_fixture(%{name: "Prep Test Game", bgg_id: 7788})

    {:ok, _doc} =
      RuleMaven.Games.create_document(%{
        game_id: game.id,
        label: "Rulebook",
        pdf_path: "uploads/rulebooks/x.pdf",
        pages: []
      })

    conn = Plug.Test.init_test_session(conn, %{"user_id" => admin.id})
    {:ok, _view, html} = live(conn, "/games/#{RuleMaven.Hashid.encode(game.id)}/prepare")

    assert html =~ "Prepare Prep Test Game"
    assert html =~ "Extract"
  end
end
