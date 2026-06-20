defmodule RuleMaven.Games.RulebookSource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rulebook_sources" do
    field :label, :string
    field :full_text, :string
    field :pdf_path, :string
    field :html_path, :string
    belongs_to :game, RuleMaven.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rulebook_source, attrs) do
    rulebook_source
    |> cast(attrs, [:label, :full_text, :game_id, :pdf_path, :html_path])
    |> validate_required([:label, :full_text, :game_id])
  end
end
