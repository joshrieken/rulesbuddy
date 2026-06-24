defmodule RuleMaven.Faq do
  @moduledoc """
  Community Q&A — counts and stats for admin-promoted QuestionLog entries.
  FaqEntry/FaqCandidate tables removed; community visibility lives on QuestionLog.
  """

  import Ecto.Query, warn: false
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Repo

  def community_count(%RuleMaven.Games.Game{} = game) do
    Repo.aggregate(
      from(q in QuestionLog,
        where: q.game_id == ^game.id and q.visibility == "community" and q.refused == false
      ),
      :count
    )
  end

  def stats do
    community = Repo.aggregate(from(q in QuestionLog, where: q.visibility == "community"), :count)
    %{community: community || 0}
  end
end
