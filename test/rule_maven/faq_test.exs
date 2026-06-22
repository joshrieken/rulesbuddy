defmodule RuleMaven.FaqTest do
  use RuleMaven.DataCase
  alias RuleMaven.{Faq, Games}
  alias RuleMaven.Repo

  setup do
    {:ok, game} = Games.create_game(%{name: "Test Game"})
    %{game: game}
  end

  test "create and list faqs", %{game: game} do
    {:ok, faq} =
      Faq.create_faq(%{
        game_id: game.id,
        canonical_question: "How many cards?",
        canonical_answer: "5 cards per player",
        source_qa_ids: [1, 2]
      })

    assert faq.status == "draft"
    assert faq.auto_approved == false

    faqs = Faq.list_faqs(game)
    assert length(faqs) == 1
  end

  test "approve and publish faq", %{game: game} do
    {:ok, faq} =
      Faq.create_faq(%{
        game_id: game.id,
        canonical_question: "Test Q",
        canonical_answer: "Test A",
        source_qa_ids: [1]
      })

    {:ok, published} = Faq.approve_faq(faq, nil)
    assert published.status == "published"

    published_faqs = Faq.list_published(game)
    assert length(published_faqs) == 1
  end

  test "discard faq", %{game: game} do
    {:ok, faq} =
      Faq.create_faq(%{
        game_id: game.id,
        canonical_question: "Discard me",
        canonical_answer: "Nope",
        source_qa_ids: [1]
      })

    {:ok, discarded} = Faq.discard_faq(faq)
    assert discarded.status == "discarded"
  end

  describe "thread consolidation" do
    setup %{game: game} do
      user =
        Repo.insert!(%RuleMaven.Users.User{
          username: "consolidate_test",
          email: "consolidate@test.com",
          password_hash: "x"
        })

      {:ok, root_q} =
        Games.log_question(%{
          game_id: game.id,
          user_id: user.id,
          question: "How many dice?",
          answer: "You roll 3 dice.",
          visibility: "community"
        })

      {:ok, fu1} =
        Games.log_question(%{
          game_id: game.id,
          user_id: user.id,
          question: "What about rerolls?",
          answer: "You may reroll one die.",
          parent_question_id: root_q.id,
          visibility: "community"
        })

      {:ok, fu2} =
        Games.log_question(%{
          game_id: game.id,
          user_id: user.id,
          question: "Can I reroll all?",
          answer: "No, only one.",
          parent_question_id: root_q.id,
          visibility: "community"
        })

      %{game: game, root_q: root_q, fu1: fu1, fu2: fu2}
    end

    test "build_consolidated_answer/2 includes root and followups", %{
      root_q: root_q,
      fu1: fu1,
      fu2: fu2
    } do
      result = Faq.build_consolidated_answer(root_q, [fu1, fu2])

      assert result =~ "Original:"
      assert result =~ "You roll 3 dice"
      assert result =~ "Follow-ups:"
      assert result =~ "What about rerolls?"
      assert result =~ "You may reroll one die"
      assert result =~ "Can I reroll all?"
      assert result =~ "No, only one."
    end

    test "build_consolidated_answer/2 handles no followups", %{root_q: root_q} do
      result = Faq.build_consolidated_answer(root_q, [])
      assert result =~ "Original:"
      assert result =~ "You roll 3 dice"
      refute result =~ "Follow-ups:"
    end

    test "consolidate_thread/3 creates a published FAQ entry", %{
      game: game,
      root_q: root_q,
      fu1: fu1,
      fu2: fu2
    } do
      {:ok, faq} = Faq.consolidate_thread(root_q, [fu1, fu2])

      assert faq.status == "published"
      assert faq.game_id == game.id
      assert faq.canonical_question == "How many dice?"
      assert faq.canonical_answer =~ "You roll 3 dice"
      assert faq.source_qa_ids == [root_q.id, fu1.id, fu2.id]

      published = Faq.list_published(game)
      assert length(published) == 1
    end

    test "consolidate_thread/3 accepts custom question and answer", %{
      root_q: root_q,
      fu1: fu1
    } do
      {:ok, faq} =
        Faq.consolidate_thread(root_q, [fu1], %{
          question: "Custom question?",
          answer: "Custom answer."
        })

      assert faq.canonical_question == "Custom question?"
      assert faq.canonical_answer == "Custom answer."
    end
  end
end
