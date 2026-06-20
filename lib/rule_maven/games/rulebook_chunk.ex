defmodule RuleMaven.Games.RulebookChunk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rulebook_chunks" do
    field :chunk_index, :integer
    field :content, :string
    belongs_to :game, RuleMaven.Games.Game
    belongs_to :rulebook_source, RuleMaven.Games.RulebookSource, foreign_key: :source_id

    timestamps(type: :utc_datetime)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:game_id, :source_id, :chunk_index, :content])
    |> validate_required([:game_id, :source_id, :chunk_index, :content])
  end
end
