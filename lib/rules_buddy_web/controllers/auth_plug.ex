defmodule RulesBuddyWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = if user_id, do: RulesBuddy.Users.get_user(user_id), else: nil
    assign(conn, :current_user, user)
  end

  def require_game_master(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      user && RulesBuddy.Users.game_master?(user) ->
        conn

      user ->
        conn
        |> put_flash(:error, "You don't have permission to do that.")
        |> redirect(to: "/")
        |> halt()

      true ->
        conn
        |> put_flash(:error, "Please log in first.")
        |> redirect(to: "/login")
        |> halt()
    end
  end

  def logged_in?(conn) do
    user = conn.assigns[:current_user]
    user != nil
  end
end
