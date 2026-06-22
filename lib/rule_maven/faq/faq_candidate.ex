defmodule RuleMaven.Faq.FaqCandidate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "faq_candidates" do
    field :question_text, :string
    field :cluster_id, :integer
    field :sample_answer_text, :string
    field :sample_citation, :string
    field :thumbs_down_count, :integer, default: 0
    field :total_asked_count, :integer, default: 0
    field :status, :string, default: "pending"
    belongs_to :game, RuleMaven.Games.Game
    belongs_to :published_faq, RuleMaven.Faq.FaqEntry

    timestamps(type: :utc_datetime)
  end

  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [
      :game_id,
      :question_text,
      :cluster_id,
      :sample_answer_text,
      :sample_citation,
      :thumbs_down_count,
      :total_asked_count,
      :status,
      :published_faq_id
    ])
    |> validate_required([:game_id, :question_text])
  end
end
