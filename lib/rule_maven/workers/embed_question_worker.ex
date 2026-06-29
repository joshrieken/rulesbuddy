defmodule RuleMaven.Workers.EmbedQuestionWorker do
  @moduledoc """
  Re-embeds a QuestionLog's canonical_question (or falls back to question)
  and stores the vector in question_embedding.
  Enqueued whenever admin sets canonical_question on a QuestionLog.
  """

  use Oban.Worker, queue: :default, max_attempts: 3
  import Ecto.Query
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"question_log_id" => id}}) do
    q = Repo.get!(QuestionLog, id)
    text = q.canonical_question || q.question

    case RuleMaven.Embed.embed(text) do
      {:ok, vector} ->
        Repo.update_all(
          from(ql in QuestionLog, where: ql.id == ^q.id),
          set: [question_embedding: Pgvector.new(vector)]
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def enqueue(question_log_id) do
    %{"question_log_id" => question_log_id}
    |> new()
    |> Oban.insert()
  end
end
