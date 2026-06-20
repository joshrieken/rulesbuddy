defmodule RuleMaven.CheatSheet do
  @moduledoc """
  Generates a cheat-sheet PDF from rulebook text using the LLM
  for content and Puppeteer for PDF rendering.
  """

  alias RuleMaven.{Games, Settings}

  @doc """
  Starts async cheat sheet generation in a background Task.
  Stores progress in Settings so it survives page refresh.
  Sends {:cheat_done, game_id} to caller when complete.
  """
  def generate_async(game, caller_pid) do
    game_id = game.id
    started = System.system_time(:second)

    Settings.put("cheat_status_#{game_id}", "compressing")
    Settings.put("cheat_content_#{game_id}", nil)
    Settings.put("cheat_error_#{game_id}", nil)
    Settings.put("cheat_started_#{game_id}", started)
    Settings.put("cheat_cancelled_#{game_id}", "false")
    Settings.put("cheat_provider_#{game_id}", RuleMaven.LLM.provider())
    Settings.put("cheat_model_#{game_id}", RuleMaven.LLM.model())

    Task.start(fn ->
      result =
        try do
          generate_content(game)
        rescue
          e ->
            {:error, "Unexpected error: #{Exception.message(e)}"}
        catch
          :exit, reason ->
            {:error, "Process exited: #{inspect(reason)}"}
        end

      elapsed = System.system_time(:second) - started

      # Don't overwrite if cancelled
      if Settings.get("cheat_cancelled_#{game_id}") == "true" do
        send(caller_pid, {:cheat_done, game_id})
      else
        case result do
          {:ok, content} ->
            Settings.put("cheat_status_#{game_id}", "done")
            Settings.put("cheat_content_#{game_id}", content)

          {:error, reason} ->
            Settings.put("cheat_status_#{game_id}", "error")
            Settings.put("cheat_error_#{game_id}", reason)
        end

        Settings.put("cheat_elapsed_#{game_id}", elapsed)
        send(caller_pid, {:cheat_done, game_id})
      end
    end)

    :ok
  end

  @doc """
  Returns current cheat generation status for a game: nil, "compressing", "done", "error".
  """
  def status(game_id) do
    Settings.get("cheat_status_#{game_id}")
  end

  @doc """
  Returns stored cheat content for a game, or nil.
  """
  def stored_content(game_id) do
    Settings.get("cheat_content_#{game_id}")
  end

  @doc """
  Returns stored cheat error for a game, or nil.
  """
  def stored_error(game_id) do
    Settings.get("cheat_error_#{game_id}")
  end

  @doc """
  Returns stored provider name, or nil.
  """
  def stored_provider(game_id) do
    Settings.get("cheat_provider_#{game_id}")
  end

  @doc """
  Returns stored model name, or nil.
  """
  def stored_model(game_id) do
    Settings.get("cheat_model_#{game_id}")
  end

  @doc """
  Returns stored elapsed seconds, or nil.
  """
  def stored_elapsed(game_id) do
    case Settings.get("cheat_elapsed_#{game_id}") do
      nil -> nil
      val ->
        case Integer.parse(val) do
          {n, _} -> n
          :error -> nil
        end
    end
  end

  @doc """
  Returns stored cheat started timestamp, or nil.
  """
  def stored_started(game_id) do
    case Settings.get("cheat_started_#{game_id}") do
      nil -> nil
      val ->
        case Integer.parse(val) do
          {n, _} -> n
          :error -> nil
        end
    end
  end

  @doc """
  Returns true if generation was cancelled for a game.
  """
  def cancelled?(game_id) do
    Settings.get("cheat_cancelled_#{game_id}") == "true"
  end

  @doc """
  Clears stored cheat state for a game.
  """
  def clear(game_id) do
    Settings.put("cheat_status_#{game_id}", nil)
    Settings.put("cheat_content_#{game_id}", nil)
    Settings.put("cheat_error_#{game_id}", nil)
    Settings.put("cheat_started_#{game_id}", nil)
    Settings.put("cheat_cancelled_#{game_id}", "true")
  end

  @doc """
  Generates cheat sheet markdown content from rulebook text.
  Returns `{:ok, markdown}` or `{:error, reason}`.
  """
  def generate_content(game) do
    full_text = Games.rulebook_text(game)

    if String.trim(full_text) == "" do
      {:error, "No rulebook text available for #{game.name}"}
    else
      annotated = annotate_pages(full_text)

      with {:ok, compressed} <- compress_text(game.name, annotated),
           {:ok, content} <- generate_cheat_sheet_content(game.name, compressed) do
        {:ok, content}
      end
    end
  end

  # Replace \f page breaks with visible [Page N] markers for LLM citation
  defp annotate_pages(text) do
    pages = String.split(text, "\f")

    if length(pages) <= 1 do
      text
    else
      pages
      |> Enum.with_index(1)
      |> Enum.map(fn {page_text, n} ->
        "[Page #{n}]\n#{String.trim(page_text)}"
      end)
      |> Enum.join("\n\n")
    end
  end

  @doc """
  Renders markdown content to a PDF and saves it to the game record.
  Returns `{:ok, pdf_path}` or `{:error, reason}`.
  """
  def generate_pdf(game, markdown) do
    with {:ok, html} <- wrap_html(game.name, markdown),
         {:ok, pdf_path} <- html_to_pdf(game, html) do
      Games.update_game(game, %{cheat_pdf_path: pdf_path})
      {:ok, pdf_path}
    end
  end

  @doc """
  Full pipeline: generate content + render PDF. Convenience.
  """
  def generate(game) do
    with {:ok, content} <- generate_content(game),
         {:ok, pdf_path} <- generate_pdf(game, content) do
      {:ok, pdf_path}
    end
  end

  # If text is under ~12k chars, no compression needed.
  # Otherwise, ask LLM to strip flavor/examples, keep only mechanical rules.
  defp compress_text(game_name, full_text) do
    if String.length(full_text) < 12_000 do
      {:ok, full_text}
    else
      system = "You are a rulebook editor. Extract ALL mechanical rules completely. Strip only flavor text and examples. Preserve [Page N] markers. Do not omit any rule."

      prompt = """
      Extract ALL mechanical rules from this rulebook. Keep every rule, number, and procedure. Remove ONLY: flavor text, lore, narrative examples, component flavor descriptions, and credits. Keep: setup steps, turn order, all phases, every rule, scoring details, win conditions, card counts, component counts, and numeric values. Preserve [Page N] markers.

      RULEBOOK:
      #{full_text}
      """

      case RuleMaven.LLM.chat(prompt, game_name, system: system, max_tokens: 8192) do
        {:ok, compressed} -> {:ok, compressed}
        {:error, _} -> {:ok, String.slice(full_text, 0, 40_000)}
      end
    end
  end

  defp generate_cheat_sheet_content(game_name, full_text) do
    system = "You are a board game rules expert. Create complete, accurate cheat sheets from rulebook text. Include EVERY rule. Use markdown. Cite [p.N] for each rule. Be thorough."

    prompt = """
    Create a complete printable cheat sheet for "#{game_name}" using ALL rules below.

    Include EVERY rule. Nothing omitted. Format as markdown:
    # {game_name}
    ## Setup
    - EVERY setup step: player count, components distributed, starting positions, initial state, first player selection [p.N]
    ## Turn Structure
    - EVERY phase in exact order, complete details of each [p.N]
    ## Key Rules
    - ALL important rules, restrictions, special cases, edge cases [p.N]
    ## Scoring / Win Conditions
    - Complete scoring rules, end-game triggers, tiebreakers [p.N]
    ## Quick Reference
    - Table of ALL important numbers: costs, limits, hand size, player counts, durations [p.N]

    Include [p.N] page citations on every bullet. Be COMPLETE, not concise. No introductions.

    RULEBOOK:
    #{full_text}
    """

    case RuleMaven.LLM.chat(prompt, game_name, system: system, max_tokens: 8192) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp wrap_html(_game_name, content) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; line-height: 1.4; color: #222; padding: 0.5in; }
        h1 { font-size: 16pt; margin-bottom: 4pt; border-bottom: 2px solid #333; padding-bottom: 4pt; }
        h2 { font-size: 12pt; margin-top: 10pt; margin-bottom: 4pt; color: #444; }
        h3 { font-size: 10pt; margin-top: 8pt; margin-bottom: 2pt; font-weight: bold; }
        ul { margin: 2pt 0; padding-left: 16pt; }
        li { margin-bottom: 1pt; }
        table { border-collapse: collapse; width: 100%; margin: 6pt 0; font-size: 9pt; }
        th, td { border: 1px solid #999; padding: 3pt 5pt; text-align: left; }
        th { background: #eee; font-weight: bold; }
        strong { color: #111; }
        p { margin: 3pt 0; }
      </style>
    </head>
    <body>
      #{markdown_to_html(content)}
    </body>
    </html>
    """

    {:ok, html}
  end

  defp markdown_to_html(md) do
    md
    |> String.replace(~r/^### (.+)$/m, "<h3>\\1</h3>")
    |> String.replace(~r/^## (.+)$/m, "<h2>\\1</h2>")
    |> String.replace(~r/^# (.+)$/m, "<h1>\\1</h1>")
    |> String.replace(~r/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.+?)\*/, "<em>\\1</em>")
    |> String.replace(~r/^- (.+)$/m, "<li>\\1</li>")
    |> wrap_lists()
    |> String.replace(~r/\n{2,}/, "</p>\n<p>")
    |> then(&"<p>#{&1}</p>")
    |> String.replace(~r/\n/, "<br>\n")
    |> String.replace(~r{<p>\s*</p>}, "")
    |> String.replace(~r{<br>\s*<br>}, "<br>")
  end

  defp wrap_lists(html) do
    html
    |> String.replace(~r/((?:^<li>.*<\/li>\n?)+)/m, "<ul>\n\\1</ul>\n")
  end

  defp html_to_pdf(game, html) do
    tmp_dir = Application.app_dir(:rule_maven, "tmp")
    File.mkdir_p!(tmp_dir)

    html_path = Path.join(tmp_dir, "#{System.system_time(:millisecond)}_cheat.html")
    File.write!(html_path, html)

    upload_dir = Application.app_dir(:rule_maven, "priv/static/uploads/rulebooks")
    File.mkdir_p!(upload_dir)

    filename = "#{System.system_time(:millisecond)}_cheatsheet_#{slug(game.name)}.pdf"
    pdf_path = Path.join("uploads/rulebooks", filename)
    dest = Application.app_dir(:rule_maven, "priv/static/#{pdf_path}")

    script = Application.app_dir(:rule_maven, "priv/scripts/html2pdf.js")

    case System.cmd("node", [script, html_path, dest], stderr_to_stdout: true) do
      {_output, 0} ->
        File.rm(html_path)
        {:ok, pdf_path}

      {output, exit_code} ->
        File.rm(html_path)
        {:error, "Puppeteer failed (exit #{exit_code}): #{String.slice(output, 0, 200)}"}
    end
  rescue
    e ->
      {:error, "PDF generation error: #{Exception.message(e)}"}
  end

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
