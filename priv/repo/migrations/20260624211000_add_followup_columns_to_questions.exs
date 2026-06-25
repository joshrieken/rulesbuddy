defmodule RuleMaven.Repo.Migrations.AddFollowupColumnsToQuestions do
  use Ecto.Migration

  # Persist the model's suggested followups / also-asked lists as columns so the
  # view reads them directly instead of re-parsing raw_response on every render.
  # Backfills existing rows from raw_response (JSON, or legacy ---MARKER--- text).
  def up do
    alter table(:questions_log) do
      add :followups, {:array, :string}, default: [], null: false
      add :also_asked, {:array, :string}, default: [], null: false
    end

    flush()

    rows = repo().query!("SELECT id, raw_response FROM questions_log WHERE raw_response IS NOT NULL")

    Enum.each(rows.rows, fn [id, raw] ->
      followups = parse(raw, "followups", "FOLLOWUPS")
      also_asked = parse(raw, "also_asked", "ALSO-ASKED")

      repo().query!(
        "UPDATE questions_log SET followups = $1, also_asked = $2 WHERE id = $3",
        [followups, also_asked, id]
      )
    end)
  end

  def down do
    alter table(:questions_log) do
      remove :followups
      remove :also_asked
    end
  end

  defp parse(raw, json_key, marker) do
    case json_list(raw, json_key) do
      nil -> marker_list(raw, marker)
      list -> list
    end
  end

  defp json_list(raw, key) do
    case Jason.decode(raw) do
      {:ok, %{} = map} ->
        case Map.get(map, key) do
          list when is_list(list) -> list |> Enum.map(&to_string/1) |> Enum.reject(&(&1 == ""))
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp marker_list(raw, marker) do
    regex = Regex.compile!("---#{marker}---\\s*\\n(.*?)\\s*---END-#{marker}---", "s")

    case Regex.run(regex, raw) do
      [_, qs] ->
        qs
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.replace(&1, ~r/^[-*]\s*/, ""))

      nil ->
        []
    end
  end
end
