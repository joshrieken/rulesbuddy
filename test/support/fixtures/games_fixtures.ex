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

  @doc """
  Generate a game with a published rulebook document, flagged `playable` so it
  appears in the default "playable" catalog view (which lists games whose
  readiness pipeline is complete — see `RuleMaven.Readiness`).
  """
  def published_game_fixture(attrs \\ %{}) do
    game = game_fixture(attrs)

    {:ok, _doc} =
      %RuleMaven.Games.Document{}
      |> RuleMaven.Games.Document.changeset(%{
        label: "Rulebook",
        full_text: "Test rulebook text.",
        game_id: game.id,
        status: "published"
      })
      |> RuleMaven.Repo.insert()

    {:ok, game} =
      game
      |> Ecto.Changeset.change(
        playable: true,
        playable_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )
      |> RuleMaven.Repo.update()

    game
  end
end
