defmodule RulesBuddy.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RulesBuddy.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        bgg_id: 42,
        name: "some name"
      })
      |> RulesBuddy.Games.create_game()

    game
  end
end
