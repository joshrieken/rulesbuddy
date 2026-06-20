defmodule RuleMaven.Settings do
  @moduledoc """
  Simple key-value application settings persisted in the database.
  """

  alias RuleMaven.Repo
  alias RuleMaven.Settings.AppSetting

  @doc "Reads a setting value by key. Returns nil if not set."
  def get(key) do
    case Repo.get(AppSetting, key) do
      %AppSetting{value: value} -> value
      nil -> nil
    end
  end

  @doc "Writes a setting value by key. Upserts to handle insert or update."
  def put(key, value) do
    case Repo.get(AppSetting, key) do
      nil -> %AppSetting{key: key}
      existing -> existing
    end
    |> AppSetting.changeset(%{key: key, value: value})
    |> Repo.insert_or_update()
  end

  @doc "Returns all settings as a map."
  def all do
    Repo.all(AppSetting)
    |> Map.new(fn %{key: key, value: value} -> {key, value} end)
  end
end
