defmodule RulesBuddyWeb.UserLiveAuth do
  import Phoenix.Component, only: [assign: 3]
  import Plug.Conn, only: [get_session: 2]

  def on_mount(:default, _params, session, socket) do
    case session[:user_id] || session["user_id"] do
      nil ->
        {:cont, assign(socket, :current_user, nil)}

      user_id ->
        user = RulesBuddy.Users.get_user(user_id)
        {:cont, assign(socket, :current_user, user)}
    end
  end

  def get_session(conn) do
    %{"user_id" => get_session(conn, :user_id)}
  end
end
