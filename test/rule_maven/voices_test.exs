defmodule RuleMaven.VoicesTest do
  use RuleMaven.DataCase

  alias RuleMaven.{Games, Repo, Voices}
  alias RuleMaven.Voices.{AnswerVoice, GameVoice}

  defp game, do: elem(Games.create_game(%{name: "V #{System.unique_integer([:positive])}"}), 1)

  defp question(game) do
    {:ok, q} = Games.log_question(%{game_id: game.id, question: "q", answer: "a"})
    q
  end

  describe "for_game / resolution" do
    test "globals are always present and neutral stays first" do
      g = game()
      defs = Voices.for_game(g)
      assert hd(defs).id == "neutral"
      ids = Enum.map(defs, & &1.id)
      assert "pirate" in ids
    end

    test "generated voices are appended and namespaced g:<slug>" do
      g = game()

      :ok =
        Voices.replace_generated(g.id, [
          %{slug: "herald", label: "Woodland Herald", emoji: "🦉", style: "a courtly herald"}
        ])

      defs = Voices.for_game(g)
      gen = Enum.find(defs, &(&1.id == "g:herald"))
      assert gen.label == "Woodland Herald"
      # globals still there, generated comes after them
      assert Enum.find(defs, &(&1.id == "pirate"))
    end

    test "valid?/2 covers globals and the game's own generated voices only" do
      g = game()
      other = game()

      :ok =
        Voices.replace_generated(g.id, [%{slug: "herald", label: "H", emoji: "🦉", style: "x"}])

      assert Voices.valid?("pirate", g)
      assert Voices.valid?("g:herald", g)
      refute Voices.valid?("g:herald", other)
      refute Voices.valid?("g:nope", g)
    end
  end

  describe "replace_generated stability" do
    test "unchanged style keeps the row id and any cached restyles" do
      g = game()
      q = question(g)

      :ok =
        Voices.replace_generated(g.id, [
          %{slug: "herald", label: "H", emoji: "🦉", style: "courtly"}
        ])

      row1 = Repo.get_by!(GameVoice, game_id: g.id, slug: "herald")

      # A paid-for restyle is cached under the namespaced id.
      Repo.insert!(%AnswerVoice{question_log_id: q.id, voice: "g:herald", content: "hark!"})

      # Re-run with the SAME style — slug stable, cache preserved.
      :ok =
        Voices.replace_generated(g.id, [
          %{slug: "herald", label: "Herald II", emoji: "🦉", style: "courtly"}
        ])

      row2 = Repo.get_by!(GameVoice, game_id: g.id, slug: "herald")
      assert row1.id == row2.id
      assert row2.label == "Herald II"
      assert Voices.get(q.id, "g:herald") == "hark!"
    end

    test "changed style drops that voice's cached restyles" do
      g = game()
      q = question(g)

      :ok =
        Voices.replace_generated(g.id, [
          %{slug: "herald", label: "H", emoji: "🦉", style: "courtly"}
        ])

      Repo.insert!(%AnswerVoice{question_log_id: q.id, voice: "g:herald", content: "hark!"})

      :ok =
        Voices.replace_generated(g.id, [
          %{slug: "herald", label: "H", emoji: "🦉", style: "GRUFF now"}
        ])

      assert Voices.get(q.id, "g:herald") == nil
    end

    test "vanished voice is deleted and its restyles cleared" do
      g = game()
      q = question(g)

      :ok =
        Voices.replace_generated(g.id, [%{slug: "herald", label: "H", emoji: "🦉", style: "x"}])

      Repo.insert!(%AnswerVoice{question_log_id: q.id, voice: "g:herald", content: "hark!"})

      :ok = Voices.replace_generated(g.id, [%{slug: "rogue", label: "R", emoji: "🗡️", style: "y"}])
      refute Repo.get_by(GameVoice, game_id: g.id, slug: "herald")
      assert Voices.get(q.id, "g:herald") == nil
      assert Repo.get_by(GameVoice, game_id: g.id, slug: "rogue")
    end
  end
end
