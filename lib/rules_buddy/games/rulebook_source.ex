defmodule RulesBuddy.Games.RulebookSource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rulebook_sources" do
    field :label, :string
    field :full_text, :string
    belongs_to :game, RulesBuddy.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rulebook_source, attrs) do
    rulebook_source
    |> cast(attrs, [:label, :full_text, :game_id])
    |> validate_required([:label, :full_text, :game_id])
  end
end
