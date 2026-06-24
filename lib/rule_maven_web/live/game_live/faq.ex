defmodule RuleMavenWeb.GameLive.Faq do
  use RuleMavenWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{id}/review")}
  end

  @impl true
  def render(assigns), do: ~H""
end
