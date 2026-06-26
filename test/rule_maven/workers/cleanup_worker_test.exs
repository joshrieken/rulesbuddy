defmodule RuleMaven.Workers.CleanupWorkerTest do
  use RuleMaven.DataCase
  use Oban.Testing, repo: RuleMaven.Repo

  alias RuleMaven.Games
  alias RuleMaven.Workers.CleanupWorker

  # Stub the LLM at do_request: uppercase the page text so the cleaned layer is
  # distinguishable and long enough to clear cleanup_page's "kept >= half" guard.
  setup do
    Application.put_env(:rule_maven, :llm_mock, fn body ->
      content = body.messages |> List.last() |> Map.fetch!(:content)
      {:ok, %{answer: String.upcase(content)}}
    end)

    on_exit(fn -> Application.delete_env(:rule_maven, :llm_mock) end)
    :ok
  end

  defp doc_with_pages(full_text) do
    {:ok, game} = Games.create_game(%{name: "Cleanup #{System.unique_integer([:positive])}"})
    {:ok, doc} = Games.create_document(%{game_id: game.id, label: "Rules", full_text: full_text})
    doc
  end

  defp run(doc) do
    job = %Oban.Job{args: %{"document_id" => doc.id, "game_id" => doc.game_id}}
    assert :ok = CleanupWorker.perform(job)
    Games.get_document!(doc.id)
  end

  test "cleans every page into the cleaned layer" do
    doc = doc_with_pages("alpha rules here\fbeta rules here\fgamma rules here")

    cleaned = run(doc) |> Map.fetch!(:pages) |> Enum.map(& &1.cleaned)

    assert cleaned == ["ALPHA RULES HERE", "BETA RULES HERE", "GAMMA RULES HERE"]
  end

  test "resumes — pages already cleaned are left untouched" do
    doc = doc_with_pages("alpha rules here\fbeta rules here\fgamma rules here")

    # Simulate a prior run that finished page 1 before a restart.
    Games.set_page_cleaned(doc.id, 1, "PRESERVED")

    pages = run(doc) |> Map.fetch!(:pages)

    assert Enum.map(pages, & &1.cleaned) == [
             "ALPHA RULES HERE",
             "PRESERVED",
             "GAMMA RULES HERE"
           ]
  end

  test "cleanup_running? reflects an active Oban job for the document" do
    doc = doc_with_pages("alpha rules here\fbeta rules here")
    refute Games.cleanup_running?(doc.id)

    # Insert the job row directly (Oban isn't supervised in test).
    %{document_id: doc.id, game_id: doc.game_id}
    |> CleanupWorker.new()
    |> Repo.insert!()

    assert Games.cleanup_running?(doc.id)
  end

  test "cleanup_running? ignores finished jobs" do
    doc = doc_with_pages("alpha rules here\fbeta rules here")

    %{document_id: doc.id, game_id: doc.game_id}
    |> CleanupWorker.new()
    |> Ecto.Changeset.put_change(:state, "completed")
    |> Repo.insert!()

    refute Games.cleanup_running?(doc.id)
  end

  test "clear_all_cleaned nulls every page's cleaned layer" do
    doc = doc_with_pages("alpha rules here\fbeta rules here")
    Games.set_page_cleaned(doc.id, 0, "STALE")

    cleared = Games.get_document!(doc.id) |> Games.clear_all_cleaned()

    assert Enum.map(cleared.pages, & &1.cleaned) == [nil, nil]
  end
end
