defmodule RuleMavenWeb.AuthController do
  use RuleMavenWeb, :controller

  def logout(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "Logged out.")
    |> redirect(to: ~p"/")
  end
end
