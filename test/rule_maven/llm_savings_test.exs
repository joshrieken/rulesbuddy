defmodule RuleMaven.LLMSavingsTest do
  use RuleMaven.DataCase

  alias RuleMaven.LLM.Savings
  alias RuleMaven.Repo

  describe "record/2" do
    test "inserts a savings row" do
      assert :ok =
               Savings.record("cache_hit", %{
                 operation: "ask",
                 estimated_tokens: 1234,
                 estimated_usd: 0.0042,
                 model: "google/gemini-2.5-flash"
               })

      row = Repo.one(Savings)
      assert row.kind == "cache_hit"
      assert row.operation == "ask"
      assert row.estimated_tokens == 1234
      assert row.estimated_usd == 0.0042
    end

    test "record never raises on bad input and returns :ok" do
      assert :ok = Savings.record("cache_hit", %{estimated_tokens: "not-an-int"})
    end
  end
end
