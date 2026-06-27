defmodule RuleMaven.Extract.GateTest do
  use ExUnit.Case, async: true

  alias RuleMaven.Extract.Gate

  @prose """
  In every game of Summer Camp you compete for merit badges in various camp
  activities: adventure, arts and crafts, cooking, friendship, games, outdoors,
  or water sports. Choose what activities you want to play this round.
  """

  describe "clean_text_layer?/1" do
    test "trusts clear, wordish prose" do
      assert Gate.clean_text_layer?(@prose)
    end

    test "rejects empty / trivial / symbol-soup layers" do
      refute Gate.clean_text_layer?("")
      refute Gate.clean_text_layer?("12")
      refute Gate.clean_text_layer?("ASE Q YopM&y AcIPa s CE (HP FW? I)")
    end
  end

  describe "agreement/2 and coverage/2" do
    test "identical text → full agreement and coverage" do
      assert Gate.agreement(@prose, @prose) == 1.0
      assert Gate.coverage(@prose, @prose) == 1.0
    end

    test "both empty → agreement 1.0 (concur: no text)" do
      assert Gate.agreement("", "") == 1.0
      assert Gate.coverage("", "") == 1.0
    end

    test "one empty → zero agreement and coverage" do
      assert Gate.agreement(@prose, "") == 0.0
      assert Gate.coverage(@prose, "") == 0.0
    end

    test "a dropped half → coverage well below 1.0" do
      half = "In every game of Summer Camp you compete for merit badges"
      assert Gate.coverage(@prose, half) < 0.7
    end
  end

  describe "assess/2" do
    test "two concurring reads → agree, no escalation, high confidence" do
      a = @prose
      b = @prose <> " A minor difference."
      r = Gate.assess(a, b)
      assert r.agree?
      refute r.escalate?
      assert r.confidence > 0.8
    end

    test "divergent reads → escalate" do
      a = @prose
      b = "ASE Q YopM&y AcIPa s CE (HP FW? I) IN IK"
      r = Gate.assess(a, b)
      refute r.agree?
      assert r.escalate?
    end

    test "a silent drop (one reader missed a chunk) → escalate" do
      a = @prose
      b = "In every game of Summer Camp you compete for merit badges"
      r = Gate.assess(a, b)
      assert r.escalate?
    end

    test "both empty (blank/art page) → agree, no endless escalation" do
      r = Gate.assess("", "")
      assert r.agree?
      refute r.escalate?
    end
  end
end
