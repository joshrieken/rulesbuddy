defmodule RuleMaven.Games.QuestionCategoryTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "question_category_tags" do
    belongs_to :question_log, RuleMaven.Games.QuestionLog
    belongs_to :game_category, RuleMaven.Games.GameCategory
    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:question_log_id, :game_category_id])
    |> validate_required([:question_log_id, :game_category_id])
    |> unique_constraint([:question_log_id, :game_category_id])
  end
end
