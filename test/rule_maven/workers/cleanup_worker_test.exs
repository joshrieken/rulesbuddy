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

  defp run(doc, extra_args \\ %{}) do
    args = Map.merge(%{"document_id" => doc.id, "game_id" => doc.game_id}, extra_args)
    assert :ok = CleanupWorker.perform(%Oban.Job{args: args})
    Games.get_document!(doc.id)
  end

  test "cleans every page into the cleaned layer" do
    doc = doc_with_pages("alpha rules here\fbeta rules here\fgamma rules here")

    cleaned = run(doc) |> Map.fetch!(:pages) |> Enum.map(& &1.cleaned)

    assert cleaned == ["ALPHA RULES HERE", "BETA RULES HERE", "GAMMA RULES HERE"]
  end

  test "durable progress counter advances then clears when done" do
    doc = doc_with_pages("alpha rules here\fbeta rules here\fgamma rules here")
    Games.set_cleaning_done(doc.id, 0)

    refreshed = run(doc)

    # All three pages persisted, and the counter is cleared (idle) on completion.
    assert Enum.count(refreshed.pages, &is_binary(&1.cleaned)) == 3
    assert Games.cleaning_done(doc.id) == nil
  end

  test "resumes the counter from its durable value instead of restarting it" do
    doc = doc_with_pages("alpha rules here\fbeta rules here\fgamma rules here")
    # Simulate a restart: page 0 already done and the counter persisted at 1.
    Games.set_page_cleaned(doc.id, 0, "ALPHA RULES HERE")
    Games.set_cleaning_done(doc.id, 1)

    # Re-fetch so perform sees the persisted counter, then run to completion.
    run(Games.get_document!(doc.id))

    # 1 (resumed) + 2 newly cleaned pages = 3 total, not 2.
    refute Games.cleanup_running?(doc.id)
    assert Games.cleaning_done(doc.id) == nil
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

  test "strips the printed page number from the body during cleanup" do
    # Marker blob gives each page a detected printed number; the footer digit
    # should be removed from the body (it's stored separately as `printed`).
    blob = Games.number_pages(["body text here\n1", "more rules text\n2"])
    {:ok, game} = Games.create_game(%{name: "Strip #{System.unique_integer([:positive])}"})
    {:ok, doc} = Games.create_document(%{game_id: game.id, label: "Rules", full_text: blob})

    pages = run(doc) |> Map.fetch!(:pages)

    assert Enum.map(pages, & &1.printed) == [1, 2]
    assert Enum.map(pages, & &1.cleaned) == ["BODY TEXT HERE", "MORE RULES TEXT"]
  end

  test "mode 'again' re-cleans the existing cleaned layer, not the raw text" do
    doc = doc_with_pages("alpha rules here\fbeta rules here")
    # A prior clean (+ hand-edit) left a distinct cleaned copy on page 0.
    Games.set_page_cleaned(doc.id, 0, "manually fixed alpha")

    pages = run(doc, %{"mode" => "again"}) |> Map.fetch!(:pages)

    # Page 0 was re-cleaned from its cleaned text (would be "ALPHA RULES HERE"
    # if it had used the raw text instead); page 1 had none, so it used raw.
    assert Enum.map(pages, & &1.cleaned) == ["MANUALLY FIXED ALPHA", "BETA RULES HERE"]
  end

  test "an unknown level falls back to light instead of crashing" do
    doc = doc_with_pages("alpha rules here\fbeta rules here")

    cleaned = run(doc, %{"level" => "bogus"}) |> Map.fetch!(:pages) |> Enum.map(& &1.cleaned)

    assert cleaned == ["ALPHA RULES HERE", "BETA RULES HERE"]
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
