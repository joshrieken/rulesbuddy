defmodule RuleMaven.Workers.DirectPromotionWorker do
  @moduledoc """
  Nightly job: promotes well-received questions to the community pool.

  Candidates are upvoted (`feedback = "up"`), non-refused, not-yet-community
  questions that carry an embedding. They are clustered by embedding similarity
  (not exact string match, so different phrasings of the same question group
  together). A cluster asked & upvoted by `@min_upvotes` distinct users promotes
  its best representative to `visibility = "community"`.
  """

  use Oban.Worker, queue: :clustering, max_attempts: 3
  import Ecto.Query
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Repo

  @min_upvotes 3
  @default_cluster_similarity 0.85

  @impl Oban.Worker
  def perform(_job) do
    Repo.all(
      from q in QuestionLog,
        where: q.feedback == "up" and q.refused == false and q.visibility != "community",
        where: not is_nil(q.question_embedding),
        select: %{
          id: q.id,
          game_id: q.game_id,
          user_id: q.user_id,
          embedding: q.question_embedding,
          has_canonical: not is_nil(q.canonical_answer),
          inserted_at: q.inserted_at
        }
    )
    |> Enum.group_by(& &1.game_id)
    |> Enum.each(fn {_game_id, rows} -> promote_clusters(rows) end)

    :ok
  end

  defp promote_clusters(rows) do
    rows
    |> cluster_by_similarity()
    |> Enum.each(fn cluster ->
      distinct_users = cluster |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()
      if distinct_users >= @min_upvotes, do: promote_representative(cluster)
    end)
  end

  # Greedy single-link clustering on cosine similarity. Each row joins the first
  # existing cluster it is close enough to, else seeds a new one.
  defp cluster_by_similarity(rows) do
    threshold = distance_threshold()

    Enum.reduce(rows, [], fn row, clusters ->
      vec = Pgvector.to_list(row.embedding)

      idx =
        Enum.find_index(clusters, fn cluster ->
          Enum.any?(cluster, fn m ->
            cosine_distance(vec, Pgvector.to_list(m.embedding)) <= threshold
          end)
        end)

      case idx do
        nil -> clusters ++ [[row]]
        i -> List.update_at(clusters, i, &[row | &1])
      end
    end)
  end

  # Prefer an admin-curated row, then the most recent.
  defp promote_representative(cluster) do
    best =
      cluster
      |> Enum.sort_by(fn r -> {r.has_canonical, r.inserted_at} end, :desc)
      |> List.first()

    Repo.update_all(
      from(q in QuestionLog, where: q.id == ^best.id),
      set: [visibility: "community"]
    )

    RuleMaven.Workers.EmbedQuestionWorker.enqueue(best.id)
  end

  defp cosine_distance(a, b) do
    dot = Enum.zip_reduce(a, b, 0.0, fn x, y, acc -> acc + x * y end)
    na = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    nb = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))
    if na == 0.0 or nb == 0.0, do: 1.0, else: 1.0 - dot / (na * nb)
  end

  defp distance_threshold do
    sim =
      case RuleMaven.Settings.get("cluster_similarity_threshold") do
        nil ->
          @default_cluster_similarity

        "" ->
          @default_cluster_similarity

        v ->
          case Float.parse(v),
            do: (
              {f, _} -> f
              :error -> @default_cluster_similarity
            )
      end

    1.0 - sim
  end
end
