defmodule RuleMavenWeb.SessionController do
  use RuleMavenWeb, :controller

  def new(conn, _params) do
    render(conn, :new, username: "", error: nil)
  end

  def create(conn, %{"session" => %{"username" => username, "password" => password}}) do
    case RuleMaven.Users.authenticate(username, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        render(conn, :new, username: username, error: reason)
    end
  end
end
