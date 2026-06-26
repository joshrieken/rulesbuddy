defmodule RuleMaven.GamesPagesTest do
  use RuleMaven.DataCase

  alias RuleMaven.Games

  describe "paginate/1" do
    test "builds first-class page maps with sheet/printed/index" do
      pages = Games.paginate(["page one", "page two", "page three"])

      assert [
               %{index: 0, sheet: 1, text: "page one"},
               %{index: 1, sheet: 2, text: "page two"},
               %{index: 2, sheet: 3, text: "page three"}
             ] = pages
    end
  end

  describe "effective_page_text/1 layer precedence" do
    test "cleaned beats original" do
      assert Games.effective_page_text(%{text: "orig", cleaned: "clean"}) == "clean"
      assert Games.effective_page_text(%{text: "orig", cleaned: nil}) == "orig"
    end

    test "empty-string cleaned still counts (not skipped as nil)" do
      assert Games.effective_page_text(%{text: "orig", cleaned: ""}) == ""
    end

    test "rebuild_full_text uses effective text" do
      pages = [%{sheet: 1, printed: 1, text: "orig", cleaned: "clean"}]
      assert Games.rebuild_full_text(pages) =~ "clean"
      refute Games.rebuild_full_text(pages) =~ "orig"
    end
  end

  describe "rebuild_full_text/1 round-trips with paginate/1" do
    test "number_pages output equals rebuild_full_text(paginate(...))" do
      raw = ["alpha", "beta", "gamma"]
      assert Games.number_pages(raw) == Games.rebuild_full_text(Games.paginate(raw))
    end

    test "marked blob parses back to equivalent pages" do
      raw = ["alpha\n1", "beta\n2", "gamma\n3"]
      blob = Games.number_pages(raw)
      parsed = Games.pages_from_full_text(blob)

      # text bodies survive the round trip
      assert Enum.map(parsed, & &1.text) == raw
      # rebuilding from parsed pages reproduces the blob
      assert Games.rebuild_full_text(parsed) == blob
    end
  end

  describe "pages_from_full_text/1" do
    test "legacy blob without markers becomes positional pages" do
      blob = "first\fsecond\fthird"
      pages = Games.pages_from_full_text(blob)

      assert [
               %{index: 0, sheet: 1, printed: nil, text: "first"},
               %{index: 1, sheet: 2, printed: nil, text: "second"},
               %{index: 2, sheet: 3, printed: nil, text: "third"}
             ] = pages
    end
  end

  describe "create_document/1 derives pages from full_text" do
    test "pages are populated and persisted" do
      {:ok, game} = Games.create_game(%{name: "Pages Test"})

      {:ok, doc} =
        Games.create_document(%{
          game_id: game.id,
          label: "Rules",
          full_text: "rule one\frule two"
        })

      assert length(doc.pages) == 2
      assert Enum.map(doc.pages, & &1.text) == ["rule one", "rule two"]
    end
  end
end
