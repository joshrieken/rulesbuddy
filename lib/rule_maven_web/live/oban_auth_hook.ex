defmodule RuleMavenWeb.ObanAuthHook do
  @moduledoc """
  LiveView on_mount hook for Oban dashboard. Only allows game_master users.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && RuleMaven.Users.game_master?(user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
