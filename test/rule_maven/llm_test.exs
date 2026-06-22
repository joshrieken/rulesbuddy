defmodule RuleMaven.LLMTest do
  use RuleMaven.DataCase

  alias RuleMaven.{LLM, Games, Faq, Repo}
  alias RuleMaven.Games.QuestionLog

  describe "response parsing" do
    test "extracts answer and citation" do
      mock_llm(fn _body ->
        {:ok,
         %{
           answer: "You move 4 spaces.",
           cited_passage: "You may move up to 4 spaces on your turn.",
           followup: false,
           followups: []
         }}
      end)

      {:ok, game} = Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "How many spaces?")

      assert result.answer =~ "You move 4 spaces"
      assert result.cited_passage =~ "You may move up to 4 spaces"
    end

    test "extracts followup flag" do
      mock_llm(fn _body ->
        {:ok, %{answer: "Yes.", cited_passage: "You may move.", followup: true, followups: []}}
      end)

      {:ok, game} = Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "Can I move?")

      assert result.followup == true
    end

    test "extracts followup suggestions" do
      mock_llm(fn _body ->
        {:ok,
         %{
           answer: "You move 4.",
           cited_passage: "You may move up to 4 spaces.",
           followup: false,
           followups: ["What if I'm on a road?", "Can I move through walls?"]
         }}
      end)

      {:ok, game} = Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "How many spaces?")

      assert length(result.followups) == 2
      assert "What if I'm on a road?" in result.followups
    end

    test "refusal response passes through correctly" do
      mock_llm(fn _body ->
        {:ok,
         %{
           answer: "The rulebook does not cover this question.",
           cited_passage: "",
           followup: false,
           followups: []
         }}
      end)

      {:ok, game} = Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "Can I trade?")

      assert result.answer =~ "does not cover"
      assert result.followups == []
    end
  end

  describe "system prompt" do
    test "includes refusal instructions" do
      {:ok, game} = Games.create_game(%{name: "Test"})
      {:ok, agent} = Agent.start_link(fn -> nil end)

      mock_llm(fn body ->
        prompt =
          body.messages |> Enum.find(&(&1.role == "system")) |> Map.get(:content)

        Agent.update(agent, fn _ -> prompt end)

        {:ok, %{answer: "ok", cited_passage: "ok", followup: false, followups: []}}
      end)

      LLM.ask(game, "hello")
      prompt = Agent.get(agent, & &1)

      assert prompt =~ "does not cover"
      assert prompt =~ "REFUSAL RULES"
    end

    test "includes recent context when provided" do
      {:ok, game} = Games.create_game(%{name: "Test"})
      {:ok, agent} = Agent.start_link(fn -> nil end)

      mock_llm(fn body ->
        prompt =
          body.messages |> Enum.find(&(&1.role == "system")) |> Map.get(:content)

        Agent.update(agent, fn _ -> prompt end)

        {:ok, %{answer: "ok", cited_passage: "ok", followup: false, followups: []}}
      end)

      LLM.ask(game, "how far?", [], [{"What can I do?", "You can move 4 spaces."}])
      prompt = Agent.get(agent, & &1)

      assert prompt =~ "RECENT CONVERSATION"
      assert prompt =~ "What can I do?"
    end
  end

  describe "pool hit cache" do
    setup do
      {:ok, game} = Games.create_game(%{name: "PoolGame"})

      user =
        Repo.insert!(%RuleMaven.Users.User{
          username: "pool_test",
          email: "pool@test.com",
          password_hash: "x"
        })

      {:ok, q} =
        Games.log_question(%{
          game_id: game.id,
          user_id: user.id,
          question: "How many dice do I roll?",
          answer: "You roll 3 six-sided dice.",
          visibility: "community"
        })

      # Update with a fake embedding for similarity match
      Repo.update_all(
        from(ql in QuestionLog, where: ql.id == ^q.id),
        set: [question_embedding: Pgvector.new(Enum.to_list(1..768))]
      )

      %{game: game}
    end

    test "returns pool hit when similar community question exists" do
      {:ok, game} = Games.create_game(%{name: "PoolHitGame"})

      user =
        Repo.insert!(%RuleMaven.Users.User{
          username: "poolhit_test2",
          email: "poolhit2@test.com",
          password_hash: "x"
        })

      # Insert a question with a known embedding
      embedding = Enum.to_list(1..768)

      Games.log_question(%{
        game_id: game.id,
        user_id: user.id,
        question: "Pool question",
        answer: "Pool answer",
        visibility: "community"
      })

      Repo.update_all(
        from(ql in QuestionLog, where: ql.game_id == ^game.id),
        set: [question_embedding: Pgvector.new(embedding)]
      )

      # Mock the embed to return the same embedding (guarantees cosine_distance ~0)
      Application.put_env(:rule_maven, :embed_mock, fn _text -> {:ok, embedding} end)

      on_exit(fn ->
        Application.delete_env(:rule_maven, :embed_mock)
      end)

      {:ok, result} = LLM.ask(game, "Any question")

      assert result.provider == "pool"
      assert result.model == "cached"
      assert result.answer == "Pool answer"
      assert result[:pool_hit] == true
    end
  end

  describe "FAQ cache with expansions" do
    test "checks FAQ across base game and expansions" do
      {:ok, base} = Games.create_game(%{name: "Base Game"})
      {:ok, exp} = Games.create_game(%{name: "Expansion", parent_game_id: base.id})

      # Create a published FAQ under the expansion
      embedding = Enum.to_list(1..768)

      {:ok, _faq} =
        Faq.create_faq(%{
          game_id: exp.id,
          canonical_question: "Expansion rule question?",
          canonical_answer: "Expansion answer.",
          source_qa_ids: [],
          status: "published",
          question_embedding: Pgvector.new(embedding)
        })

      # Mock embed to return the matching embedding
      Application.put_env(:rule_maven, :embed_mock, fn _text -> {:ok, embedding} end)

      on_exit(fn ->
        Application.delete_env(:rule_maven, :embed_mock)
      end)

      # Ask with expansion included
      {:ok, result} = LLM.ask(base, "Expansion question", [exp.id])

      assert result[:faq_hit] == true
      assert result.answer == "Expansion answer."
      assert result.provider == "faq"
    end

    test "FAQ miss when expansion not included" do
      {:ok, base} = Games.create_game(%{name: "Base2"})
      {:ok, exp} = Games.create_game(%{name: "Exp2", parent_game_id: base.id})

      # Create FAQ under expansion
      {:ok, _faq} =
        Faq.create_faq(%{
          game_id: exp.id,
          canonical_question: "Exp only Q",
          canonical_answer: "Exp only A",
          source_qa_ids: [],
          status: "published"
        })

      # No expansion included, should go to LLM
      mock_llm(fn _body ->
        {:ok, %{answer: "LLM answer", cited_passage: "Passage", followup: false, followups: []}}
      end)

      {:ok, result} = LLM.ask(base, "Exp only Q")

      # Should NOT be a FAQ hit since expansion wasn't passed
      assert result[:faq_hit] == false
      assert result.answer == "LLM answer"
    end
  end

  defp mock_llm(fun) do
    Application.put_env(:rule_maven, :llm_mock, fun)

    on_exit(fn ->
      Application.delete_env(:rule_maven, :llm_mock)
    end)
  end
end
