defmodule RulesBuddy.Games.QuestionLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questions_log" do
    field :question, :string
    field :answer, :string
    field :cited_passage, :string
    belongs_to :game, RulesBuddy.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(question_log, attrs) do
    question_log
    |> cast(attrs, [:question, :answer, :cited_passage, :game_id])
    |> validate_required([:question, :answer, :game_id])
  end
end
