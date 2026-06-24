defmodule RuleMaven.Workers.DirectPromotionWorker do
  @moduledoc """
  Nightly job: finds questions with 3+ upvotes not yet community-visible
  and promotes them by setting visibility=community on the best answer.
  """

  use Oban.Worker, queue: :clustering, max_attempts: 3
  import Ecto.Query
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Repo

  @min_upvotes 3

  @impl Oban.Worker
  def perform(_job) do
    upvoted =
      Repo.all(
        from q in QuestionLog,
          where: q.feedback == "up" and q.refused == false and q.visibility != "community",
          group_by: [q.game_id, q.question],
          having: count(q.id) >= @min_upvotes,
          select: %{game_id: q.game_id, question: q.question}
      )

    Enum.each(upvoted, &promote_best_answer/1)
    :ok
  end

  defp promote_best_answer(%{game_id: game_id, question: question}) do
    best =
      Repo.one(
        from q in QuestionLog,
          where:
            q.game_id == ^game_id and q.question == ^question and q.feedback == "up" and
              q.refused == false,
          order_by: [desc: not is_nil(q.question_embedding)],
          limit: 1
      )

    if best do
      Repo.update_all(
        from(q in QuestionLog, where: q.id == ^best.id),
        set: [visibility: "community"]
      )

      RuleMaven.Workers.EmbedQuestionWorker.enqueue(best.id)
    end
  end
end
