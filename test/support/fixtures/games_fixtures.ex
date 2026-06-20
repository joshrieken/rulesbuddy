defmodule RuleMaven.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RuleMaven.Games` context.
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
      |> RuleMaven.Games.create_game()

    game
  end
end
