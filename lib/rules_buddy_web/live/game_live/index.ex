defmodule RulesBuddyWeb.GameLive.Index do
  use RulesBuddyWeb, :live_view

  alias RulesBuddy.Games

  @impl true
  def mount(_params, _session, socket) do
    games = Games.list_games()
    {:ok, assign(socket, games: games)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-list">
      <h1 class="text-2xl font-bold mb-6">Rules Buddy</h1>

      <div :if={RulesBuddy.Users.game_master?(@current_user)} class="mb-6">
        <.button variant="primary" navigate={~p"/games/new"}>
          + Add Game
        </.button>
      </div>

      <div class="space-y-3">
        <%= for game <- @games do %>
          <div class="border rounded-lg p-4 flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">{game.name}</h2>
              <p class="text-sm text-gray-500">
                {length(Games.list_rulebook_sources(game))} rulebook source(s)
              </p>
            </div>
            <div class="flex gap-2">
              <.link navigate={~p"/games/#{game.id}"} class="text-blue-600 hover:underline">
                Ask
              </.link>
              <.link
                :if={RulesBuddy.Users.game_master?(@current_user)}
                navigate={~p"/games/#{game.id}/edit"}
                class="text-gray-600 hover:underline"
              >
                Edit
              </.link>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @games == [] do %>
        <div class="text-center py-12 text-gray-500">
          <p class="text-lg">No games yet.</p>
          <p>Add a game to get started!</p>
        </div>
      <% end %>
    </div>
    """
  end
end
