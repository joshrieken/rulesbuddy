defmodule RuleMaven.Metrics do
  @moduledoc """
  Usage metrics. Currently tracks theme selections so we can see which themes
  people actually pick.
  """

  import Ecto.Query
  alias RuleMaven.Repo
  alias RuleMaven.Metrics.ThemeEvent

  # Slug -> human label, in the order shown in the theme picker. The slugs are
  # the `data-theme` values; the labels are what the user sees.
  @themes [
    {"ocean", "Abyss"},
    {"arcade", "Arcade"},
    {"brass", "Brass"},
    {"forest", "Canopy"},
    {"retro", "Cassette"},
    {"coral", "Coral"},
    {"scary", "Crypt"},
    {"sunset", "Dusk"},
    {"ember", "Ember"},
    {"frost", "Frost"},
    {"happy", "Golden Hour"},
    {"honey", "Honey"},
    {"light", "Lavender"},
    {"marble", "Marble"},
    {"meadow", "Meadow"},
    {"dark", "Midnight"},
    {"scifi", "Nebula"},
    {"matrix", "Neon"},
    {"fantasy", "Parchment"},
    {"twilight", "Twilight"},
    {"void", "Void"}
  ]

  @doc "Ordered list of `{slug, label}` for every selectable theme."
  def themes, do: @themes

  @doc "Allowlist of valid theme slugs."
  def theme_slugs, do: Enum.map(@themes, &elem(&1, 0))

  @doc "Map of slug => label."
  def theme_labels, do: Map.new(@themes)

  @doc """
  Records that `theme` was selected. `user_id` may be nil for logged-out
  visitors. Invalid (non-allowlisted) themes are dropped, returning `:error`.
  """
  def record_theme(theme, user_id \\ nil) do
    %ThemeEvent{}
    |> ThemeEvent.changeset(%{theme: theme, user_id: user_id})
    |> Repo.insert()
    |> case do
      {:ok, event} -> {:ok, event}
      {:error, _changeset} -> :error
    end
  end

  @doc """
  Selection counts per theme as a map of `slug => count`. Themes that have
  never been picked are omitted; callers can fall back to `theme_labels/0`.
  """
  def theme_counts do
    ThemeEvent
    |> group_by([e], e.theme)
    |> select([e], {e.theme, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Total number of recorded theme selections."
  def total_theme_events do
    Repo.aggregate(ThemeEvent, :count, :id)
  end
end
