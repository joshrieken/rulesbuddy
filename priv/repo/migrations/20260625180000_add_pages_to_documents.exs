defmodule RuleMaven.Repo.Migrations.AddPagesToDocuments do
  use Ecto.Migration

  import Ecto.Query
  alias RuleMaven.Repo
  alias RuleMaven.Games.Document

  # Leading per-page marker written into full_text at extraction time.
  @page_marker ~r/\A=+\s*SHEET\s+(\d+)(?:\s+PAGE\s+(\d+))?\s*=+[ \t]*\r?\n?/i

  def up do
    alter table(:documents) do
      add :pages, {:array, :map}, default: []
    end

    flush()

    # Backfill first-class pages from each document's existing marker-delimited
    # full_text blob.
    for %{id: id, full_text: full_text} <-
          Repo.all(from(d in "documents", select: %{id: d.id, full_text: d.full_text})) do
      doc = Repo.get!(Document, id)

      doc
      |> Document.changeset(%{pages: parse_pages(full_text || "")})
      |> Repo.update!()
    end
  end

  def down do
    alter table(:documents) do
      remove :pages
    end
  end

  defp parse_pages(text) do
    segments =
      text
      |> String.split("\f")
      |> Enum.reject(&(String.trim(&1) == ""))

    if Enum.any?(segments, &has_marker?/1) do
      segments
      |> Enum.flat_map(fn seg ->
        case Regex.run(@page_marker, seg) do
          [matched, sheet, printed] ->
            [%{sheet: to_int(sheet), printed: to_int(printed), text: strip(seg, matched)}]

          [matched, sheet] ->
            [%{sheet: to_int(sheet), printed: nil, text: strip(seg, matched)}]

          _ ->
            []
        end
      end)
      |> Enum.with_index()
      |> Enum.map(fn {p, i} -> Map.put(p, :index, i) end)
    else
      segments
      |> Enum.with_index()
      |> Enum.map(fn {seg, i} -> %{index: i, sheet: i + 1, printed: nil, text: seg} end)
    end
  end

  defp has_marker?(seg), do: Regex.match?(@page_marker, seg)
  defp strip(seg, matched), do: String.replace_prefix(seg, matched, "")
  defp to_int(s), do: String.to_integer(s)
end
