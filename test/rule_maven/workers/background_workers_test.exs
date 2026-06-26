defmodule RuleMaven.Workers.BackgroundWorkersTest do
  use RuleMaven.DataCase

  alias RuleMaven.{Games, Settings}
  alias RuleMaven.Workers.{SuggestionsWorker, CategoriesWorker, CheatSheetGenWorker, DownloadWorker}

  # Stub the LLM at the do_request boundary. Each test sets its own answer.
  defp mock_llm(answer) do
    Application.put_env(:rule_maven, :llm_mock, fn _body -> {:ok, %{answer: answer}} end)
    on_exit(fn -> Application.delete_env(:rule_maven, :llm_mock) end)
  end

  defp game_with_rulebook do
    {:ok, game} = Games.create_game(%{name: "Worker #{System.unique_integer([:positive])}"})

    {:ok, _doc} =
      Games.create_document(%{
        game_id: game.id,
        label: "Rules",
        full_text: String.duplicate("setup draw cards then play and score points. ", 50)
      })

    game
  end

  describe "SuggestionsWorker" do
    test "persists suggestions and broadcasts to the game topic" do
      mock_llm("CATEGORY: Setup\n- How many cards do I draw?\n- Who goes first?")
      game = game_with_rulebook()
      Phoenix.PubSub.subscribe(RuleMaven.PubSub, SuggestionsWorker.topic(game.id))

      assert :ok = SuggestionsWorker.perform(%Oban.Job{args: %{"game_id" => game.id}})

      assert_received {:suggestions_ready, [%{category: "Setup", questions: qs}]}
      assert "How many cards do I draw?" in qs
      assert Settings.get("suggestions_#{game.id}") =~ "Setup"
    end
  end

  describe "CategoriesWorker" do
    test "persists categories and broadcasts" do
      mock_llm("Strategy, Card Game, Engine Building")
      game = game_with_rulebook()
      Phoenix.PubSub.subscribe(RuleMaven.PubSub, CategoriesWorker.topic(game.id))

      assert :ok = CategoriesWorker.perform(%Oban.Job{args: %{"game_id" => game.id}})

      assert_received {:categories_ready, cats}
      assert is_list(cats)
      assert Settings.get("categories_#{game.id}") != nil
    end
  end

  describe "CheatSheetGenWorker" do
    test "writes the cheat-sheet state machine and broadcasts done" do
      mock_llm("## Essentials\n- Draw **2** cards.")
      game = game_with_rulebook()
      Settings.put("cheat_started_#{game.id}", System.system_time(:second))
      Settings.put("cheat_cancelled_#{game.id}", "false")
      Phoenix.PubSub.subscribe(RuleMaven.PubSub, CheatSheetGenWorker.topic(game.id))

      args = %{"game_id" => game.id, "level" => "compact", "expansion_ids" => []}
      assert :ok = CheatSheetGenWorker.perform(%Oban.Job{args: args})

      assert_received {:cheat_done, game_id} when game_id == game.id
      assert Settings.get("cheat_status_#{game.id}") == "done"
      assert Settings.get("cheat_content_#{game.id}") =~ "Essentials"
    end

    test "does not overwrite a cancelled generation" do
      mock_llm("## Essentials\n- Draw **2** cards.")
      game = game_with_rulebook()
      Settings.put("cheat_started_#{game.id}", System.system_time(:second))
      Settings.put("cheat_cancelled_#{game.id}", "true")

      args = %{"game_id" => game.id, "level" => "compact", "expansion_ids" => []}
      assert :ok = CheatSheetGenWorker.perform(%Oban.Job{args: args})

      refute Settings.get("cheat_status_#{game.id}") == "done"
    end
  end

  describe "DownloadWorker durable state" do
    test "running? reflects an active job for the game" do
      {:ok, game} = Games.create_game(%{name: "DL #{System.unique_integer([:positive])}"})
      refute DownloadWorker.running?(game.id)

      %{game_id: game.id, mode: "find", url: nil, label: ""}
      |> DownloadWorker.new()
      |> RuleMaven.Repo.insert!()

      assert DownloadWorker.running?(game.id)
    end

    test "running? ignores finished jobs" do
      {:ok, game} = Games.create_game(%{name: "DL #{System.unique_integer([:positive])}"})

      %{game_id: game.id, mode: "find", url: nil, label: ""}
      |> DownloadWorker.new()
      |> Ecto.Changeset.put_change(:state, "completed")
      |> RuleMaven.Repo.insert!()

      refute DownloadWorker.running?(game.id)
    end

    test "enqueue clears a prior download error" do
      {:ok, game} = Games.create_game(%{name: "DL #{System.unique_integer([:positive])}"})
      Settings.put("download_error_#{game.id}", "boom")

      assert :ok = DownloadWorker.enqueue(game.id, "find")
      assert Settings.get("download_error_#{game.id}") == nil
    end
  end
end
