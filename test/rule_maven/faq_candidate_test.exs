defmodule RuleMaven.FaqCandidateTest do
  use RuleMaven.DataCase

  alias RuleMaven.Faq
  alias RuleMaven.Games

  setup do
    {:ok, game} = Games.create_game(%{name: "Test Game for FAQ Candidates"})
    {:ok, game: game}
  end

  test "upsert_candidate creates a new candidate", %{game: game} do
    {:ok, candidate} =
      Faq.upsert_candidate(%{
        game_id: game.id,
        question_text: "How do I move?",
        sample_answer_text: "You move 4 spaces.",
        sample_citation: "Movement rules page 3",
        thumbs_down_count: 3,
        total_asked_count: 5,
        status: "pending"
      })

    assert candidate.game_id == game.id
    assert candidate.question_text == "How do I move?"
    assert candidate.status == "pending"
    assert candidate.thumbs_down_count == 3
  end

  test "upsert_candidate updates existing candidate with same game+question", %{game: game} do
    Faq.upsert_candidate(%{
      game_id: game.id,
      question_text: "How do I move?",
      thumbs_down_count: 1,
      total_asked_count: 2
    })

    {:ok, updated} =
      Faq.upsert_candidate(%{
        game_id: game.id,
        question_text: "How do I move?",
        thumbs_down_count: 5,
        total_asked_count: 10
      })

    assert updated.thumbs_down_count == 5
    assert updated.total_asked_count == 10
  end

  test "list_pending_candidates returns only pending", %{game: game} do
    Faq.upsert_candidate(%{
      game_id: game.id,
      question_text: "Q1?",
      status: "pending",
      thumbs_down_count: 2,
      total_asked_count: 3
    })

    Faq.upsert_candidate(%{
      game_id: game.id,
      question_text: "Q2?",
      status: "approved",
      thumbs_down_count: 1,
      total_asked_count: 2
    })

    pending = Faq.list_pending_candidates(game)
    assert length(pending) == 1
    assert hd(pending).question_text == "Q1?"
  end

  test "approve_candidate creates faq_entry and links it", %{game: game} do
    {:ok, candidate} =
      Faq.upsert_candidate(%{
        game_id: game.id,
        question_text: "How to trade?",
        sample_answer_text: "Trading is allowed with consent.",
        thumbs_down_count: 2,
        total_asked_count: 4
      })

    {:ok, faq_entry} = Faq.approve_candidate(candidate)

    assert faq_entry.canonical_question == "How to trade?"
    assert faq_entry.canonical_answer == "Trading is allowed with consent."
    assert faq_entry.status == "published"

    # Candidate should be updated
    updated = Faq.get_candidate!(candidate.id)
    assert updated.status == "approved"
    assert updated.published_faq_id == faq_entry.id
  end

  test "reject_candidate marks as rejected", %{game: game} do
    {:ok, candidate} =
      Faq.upsert_candidate(%{
        game_id: game.id,
        question_text: "Bad question",
        thumbs_down_count: 10,
        total_asked_count: 12
      })

    {:ok, rejected} = Faq.reject_candidate(candidate)
    assert rejected.status == "rejected"
  end

  test "list_pending_candidates sorted by thumbs_down desc", %{game: game} do
    Faq.upsert_candidate(%{
      game_id: game.id,
      question_text: "Low priority",
      thumbs_down_count: 1,
      total_asked_count: 100
    })

    Faq.upsert_candidate(%{
      game_id: game.id,
      question_text: "High priority",
      thumbs_down_count: 10,
      total_asked_count: 5
    })

    pending = Faq.list_pending_candidates(game)
    assert hd(pending).question_text == "High priority"
  end
end
