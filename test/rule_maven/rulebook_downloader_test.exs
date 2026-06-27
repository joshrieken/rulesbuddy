defmodule RuleMaven.RulebookDownloaderTest do
  use ExUnit.Case, async: true

  alias RuleMaven.RulebookDownloader, as: RD

  describe "ocr_junk?/1 (vision-fallback trigger)" do
    test "empty / image-only page is junk (vision should try)" do
      assert RD.ocr_junk?("")
      assert RD.ocr_junk?("   \n  ")
      assert RD.ocr_junk?(nil)
    end

    test "real rules prose is not junk" do
      text = """
      In every game of Summer Camp, you will compete for merit badges in various
      camp activities: adventure, arts and crafts, cooking, friendship, games,
      outdoors, or water sports. Choose what activities you want to play.
      """

      refute RD.ocr_junk?(text)
    end

    test "a recoverable component list is not junk" do
      text = "WHAT'S INSIDE\n- 64 base cards\n- 196 activity cards\n- 6 merit badges"
      refute RD.ocr_junk?(text)
    end

    test "graphic-page symbol soup is junk" do
      # Verbatim tesseract output from a graphics-heavy cover/diagram page.
      text = "ASE Q YopM&y AcIPa s\nCE (HP FW? I) IN IK (3)\nq ® 7, | ¥ i p | / 4, x ¢ 1 ~S \\S"
      assert RD.ocr_junk?(text)
    end

    test "a lone page number is junk (no real words)" do
      assert RD.ocr_junk?("12")
    end

    test "a single legitimate word heading is not junk" do
      refute RD.ocr_junk?("Setup")
    end

    test "punctuated prose is not junk (delegates to Gate, which strips edge punctuation)" do
      # Pre-delegation this misclassified: trailing commas/periods failed the
      # word regex, dropping the wordish ratio below 0.5 on clean prose.
      text = "Choose your activities: adventure, cooking, friendship, and games."
      refute RD.ocr_junk?(text)
    end
  end
end
