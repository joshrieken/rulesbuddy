defmodule RuleMaven.Extract.NativeTest do
  use ExUnit.Case, async: true

  alias RuleMaven.Extract.Native

  describe "native?/1 and ext/1" do
    test "classifies native text formats, not pdf/images" do
      assert Native.native?("rules.docx")
      assert Native.native?("/tmp/a.XLSX")
      assert Native.native?("guide.md")
      refute Native.native?("rulebook.pdf")
      refute Native.native?("scan.png")
    end
  end

  describe "docx_text/1" do
    test "joins runs within a paragraph, splits paragraphs, decodes entities" do
      xml = """
      <w:body>
        <w:p><w:r><w:t>Setup &amp; </w:t></w:r><w:r><w:t>Play</w:t></w:r></w:p>
        <w:p><w:r><w:t xml:space="preserve">Place 3 cubes.</w:t></w:r></w:p>
      </w:body>
      """

      assert Native.docx_text(xml) == "Setup & Play\n\nPlace 3 cubes."
    end
  end

  describe "odt_text/1" do
    test "strips spans, splits on paragraphs and headings" do
      xml =
        "<text:h>Scoring</text:h><text:p>Each <text:span>victory</text:span> point counts.</text:p>"

      assert Native.odt_text(xml) == "Scoring\n\nEach victory point counts."
    end
  end

  describe "html_to_text/1" do
    test "drops scripts/styles, blocks become newlines, entities decoded" do
      html = """
      <html><head><style>.x{color:red}</style></head>
      <body><h1>Rules</h1><script>evil()</script>
      <p>Roll &amp; move.</p><p>Then score.</p></body></html>
      """

      out = Native.html_to_text(html)
      assert out =~ "Rules"
      assert out =~ "Roll & move."
      assert out =~ "Then score."
      refute out =~ "evil()"
      refute out =~ "color:red"
    end
  end

  describe "csv_to_table/1" do
    test "renders a Markdown table with header separator" do
      csv = "Name,Cost\nWorker,2\nScout,1\n"
      out = Native.csv_to_table(csv)

      assert out ==
               "| Name | Cost |\n| --- | --- |\n| Worker | 2 |\n| Scout | 1 |"
    end

    test "empty input → empty string" do
      assert Native.csv_to_table("") == ""
    end
  end

  describe "xlsx shared_strings/1 and sheet_table/2" do
    test "resolves shared-string cells in column order" do
      shared = Native.shared_strings("<sst><si><t>Name</t></si><si><t>Cost</t></si></sst>")
      assert shared == ["Name", "Cost"]

      sheet = """
      <worksheet><sheetData>
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
        <row r="2"><c r="A2"><v>Worker</v></c><c r="B2"><v>2</v></c></row>
      </sheetData></worksheet>
      """

      out = Native.sheet_table(sheet, shared)
      assert out == "| Name | Cost |\n| --- | --- |\n| Worker | 2 |"
    end

    test "out-of-order cells are sorted by column" do
      sheet = ~s(<row r="1"><c r="B1"><v>second</v></c><c r="A1"><v>first</v></c></row>)
      out = Native.sheet_table(sheet, [])
      assert out == "| first | second |\n| --- | --- |"
    end
  end
end
