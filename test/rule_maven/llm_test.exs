defmodule RuleMaven.LLMTest do
  use RuleMaven.DataCase

  alias RuleMaven.LLM

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

      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "How many spaces?")

      assert result.answer =~ "You move 4 spaces"
      assert result.cited_passage =~ "You may move up to 4 spaces"
    end

    test "extracts followup flag" do
      mock_llm(fn _body ->
        {:ok, %{answer: "Yes.", cited_passage: "You may move.", followup: true, followups: []}}
      end)

      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})

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

      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})

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

      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})

      {:ok, result} = LLM.ask(game, "Can I trade?")

      assert result.answer =~ "does not cover"
      assert result.followups == []
    end
  end

  describe "system prompt" do
    test "includes refusal instructions" do
      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})
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
      {:ok, game} = RuleMaven.Games.create_game(%{name: "Test"})
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

  defp mock_llm(fun) do
    Application.put_env(:rule_maven, :llm_mock, fun)

    on_exit(fn ->
      Application.delete_env(:rule_maven, :llm_mock)
    end)
  end
end
