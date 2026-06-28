defmodule RuleMavenWeb.UserLiveAuth do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]
  import Plug.Conn, only: [get_session: 2]

  def on_mount(:default, _params, session, socket) do
    case active_user(session) do
      nil ->
        {:halt, redirect(socket, to: "/login")}

      user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end

  def on_mount(:admin, _params, session, socket) do
    case active_user(session) do
      nil ->
        {:halt, redirect(socket, to: "/login")}

      user ->
        if RuleMaven.Users.can?(user, :admin) do
          {:cont, assign(socket, :current_user, user)}
        else
          {:halt, redirect(socket, to: "/")}
        end
    end
  end

  def on_mount(:public, _params, session, socket) do
    {:cont, assign(socket, :current_user, active_user(session))}
  end

  # Resolves the session's user, treating a suspended account as logged out.
  defp active_user(session) do
    case session[:user_id] || session["user_id"] do
      nil ->
        nil

      user_id ->
        case RuleMaven.Users.get_user(user_id) do
          nil -> nil
          user -> if RuleMaven.Users.suspended?(user), do: nil, else: user
        end
    end
  end

  def get_session(conn) do
    %{"user_id" => get_session(conn, :user_id)}
  end
end
