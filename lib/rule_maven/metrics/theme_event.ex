defmodule RuleMaven.Metrics.ThemeEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "theme_events" do
    field :theme, :string
    belongs_to :user, RuleMaven.Users.User

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:theme, :user_id])
    |> validate_required([:theme])
    |> validate_inclusion(:theme, RuleMaven.Metrics.theme_slugs())
  end
end
