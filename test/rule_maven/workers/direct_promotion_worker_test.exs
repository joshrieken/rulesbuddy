defmodule RuleMaven.Workers.DirectPromotionWorkerTest do
  use RuleMaven.DataCase

  import RuleMaven.GamesFixtures

  alias RuleMaven.Games
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Repo
  alias RuleMaven.Users
  alias RuleMaven.Users.User
  alias RuleMaven.Workers.DirectPromotionWorker

  defp user_fixture(name) do
    {:ok, u} =
      Users.create_user(%{username: name, email: "#{name}@test.com", password: "testpass1234"})

    u
  end

  defp pooled_row(game, author, trust, embedding) do
    {:ok, q} =
      Games.log_question(%{
        game_id: game.id,
        user_id: author.id,
        question: "How does scoring work?",
        answer: "Score like so.",
        cited_passage: "p.3",
        visibility: "private",
        pooled: true,
        trust_score: trust
      })

    Repo.update_all(
      from(r in QuestionLog, where: r.id == ^q.id),
      set: [question_embedding: Pgvector.new(embedding)]
    )

    q
  end

  setup do
    RuleMaven.Settings.put("promotion_floor", "3.0")
    %{game: game_fixture(), author: user_fixture("author")}
  end

  test "promotes a pooled row above the floor and rewards the author", %{
    game: game,
    author: author
  } do
    row = pooled_row(game, author, 5.0, Enum.to_list(1..768))

    assert :ok == DirectPromotionWorker.perform(%Oban.Job{args: %{}})

    assert Repo.get(QuestionLog, row.id).visibility == "community"
    assert Repo.get(User, author.id).reputation > 0
  end

  test "leaves a below-floor row private", %{game: game, author: author} do
    row = pooled_row(game, author, 1.0, Enum.to_list(1..768))

    assert :ok == DirectPromotionWorker.perform(%Oban.Job{args: %{}})

    assert Repo.get(QuestionLog, row.id).visibility == "private"
  end
end
