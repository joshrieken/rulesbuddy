defmodule RuleMaven.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias RuleMaven.Repo

  alias RuleMaven.Games.Game
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Games.Document
  alias RuleMaven.Games.Chunk
  alias Oban

  # ── Games ──

  def list_games, do: Repo.all(Game)

  def list_games_with_documents do
    # Base games + expansions that have published documents.
    # Returns base games sorted by name.
    base_ids =
      Repo.all(
        from g in Game,
          join: d in Document,
          on: d.game_id == g.id,
          where: d.status == "published",
          where: is_nil(g.parent_game_id),
          distinct: true,
          select: g.id
      )

    Repo.all(from g in Game, where: g.id in ^base_ids)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def list_base_games do
    Repo.all(from g in Game, where: is_nil(g.parent_game_id))
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def expansions_for(%Game{} = game) do
    Repo.all(from g in Game, where: g.parent_game_id == ^game.id)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def expansions_with_documents(%Game{} = base_game) do
    Repo.all(
      from g in Game,
        join: d in Document,
        on: d.game_id == g.id,
        where: g.parent_game_id == ^base_game.id,
        where: d.status == "published",
        distinct: true,
        select: g
    )
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def base_game_for(%Game{} = game) do
    if game.parent_game_id do
      Repo.get(Game, game.parent_game_id)
    end
  end

  def get_game!(id), do: Repo.get!(Game, id)

  def create_game(attrs) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def delete_game(%Game{} = game) do
    Repo.delete_all(from d in Document, where: d.game_id == ^game.id)
    Repo.delete_all(from q in QuestionLog, where: q.game_id == ^game.id)
    Repo.delete_all(from f in "faq_entries", where: f.game_id == ^game.id)
    Repo.delete(game)
  end

  def delete_all_games do
    Repo.delete_all(Document)
    Repo.delete_all(QuestionLog)
    Repo.delete_all("faq_entries")
    {count, _} = Repo.delete_all(Game)
    {count, nil}
  end

  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  # ── Documents ──

  def list_documents(%Game{} = game) do
    Repo.all(from d in Document, where: d.game_id == ^game.id)
  end

  def create_document(attrs) do
    # Auto-publish if quality looks good
    status =
      if RuleMaven.Settings.get("auto_approve_documents") != "false" and
           quality_ok?(attrs[:full_text] || "") do
        "published"
      else
        "pending_review"
      end

    result =
      %Document{}
      |> Document.changeset(Map.put(attrs, :status, status))
      |> Repo.insert()

    case result do
      {:ok, doc} ->
        chunk_document(doc)

        # Enqueue cheatsheet generation (skip in test)
        unless testing?() do
          %{document_id: doc.id}
          |> RuleMaven.Workers.CheatSheetWorker.new()
          |> Oban.insert()
        end

        {:ok, doc}

      error ->
        error
    end
  end

  defp quality_ok?(text) do
    stripped = String.trim(text)

    # Too short = garbage
    if String.length(stripped) < 500 do
      false
    else
      # Check ratio of dictionary-like words
      words = String.split(stripped, ~r/\s+/)
      total = length(words)

      if total == 0 do
        false
      else
        # Words that look like English: contain at least one vowel
        valid =
          Enum.count(words, fn w ->
            String.match?(String.downcase(w), ~r/[aeiou]/) and
              String.length(w) >= 2
          end)

        ratio = valid / total
        ratio >= 0.7
      end
    end
  end

  defp testing? do
    Application.get_env(:rule_maven, Oban)[:testing] == :manual
  end

  def get_document!(id), do: Repo.get!(Document, id)

  def update_document(%Document{} = doc, attrs) do
    doc
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  def delete_document(%Document{} = doc) do
    Repo.delete_all(from c in Chunk, where: c.document_id == ^doc.id)
    Repo.delete(doc)
  end

  def document_full_text(%Game{} = game) do
    game
    |> list_documents()
    |> Enum.map_join("\n\n", & &1.full_text)
  end

  # Backward compat aliases
  defdelegate list_rulebook_sources(game), to: __MODULE__, as: :list_documents
  defdelegate create_rulebook_source(attrs), to: __MODULE__, as: :create_document
  defdelegate delete_rulebook_source(doc), to: __MODULE__, as: :delete_document
  defdelegate rulebook_text(game), to: __MODULE__, as: :document_full_text

  def rulebook_text_for_games(game_ids) do
    game_ids
    |> Enum.map(fn gid ->
      game = Repo.get!(Game, gid)
      text = document_full_text(game)
      "--- #{game.name} ---\n#{text}"
    end)
    |> Enum.reject(fn t -> String.trim(t) == "---" end)
    |> Enum.join("\n\n")
  end

  # ── Question Log ──

  def log_question(attrs) do
    %QuestionLog{}
    |> QuestionLog.changeset(attrs)
    |> Repo.insert()
  end

  def log_question_update(%QuestionLog{} = q, attrs) do
    q
    |> QuestionLog.changeset(attrs)
    |> Repo.update()
  end

  def question_count(%Game{} = game) do
    Repo.aggregate(from(q in QuestionLog, where: q.game_id == ^game.id), :count)
  end

  def recent_question_count(user_id, since) do
    Repo.aggregate(
      from(q in QuestionLog,
        where: q.user_id == ^user_id and q.inserted_at >= ^since
      ),
      :count
    )
  end

  def grouped_questions(%Game{} = game) do
    game
    |> recent_questions(100)
    |> Enum.group_by(&String.downcase(String.trim(&1.question)))
    |> Enum.map(fn {_key, entries} ->
      sorted =
        entries
        |> Enum.sort(fn a, b ->
          case {a.pinned, b.pinned} do
            {true, false} -> true
            {false, true} -> false
            _ -> NaiveDateTime.compare(a.inserted_at, b.inserted_at) == :gt
          end
        end)

      primary = List.first(sorted)
      history = if length(sorted) > 1, do: tl(sorted), else: []
      %{primary: primary, history: history}
    end)
    |> Enum.sort_by(& &1.primary.inserted_at, {:desc, DateTime})
  end

  def pin_question(%QuestionLog{} = q) do
    Repo.update_all(
      from(ql in QuestionLog,
        where:
          ql.game_id == ^q.game_id and
            ql.question == ^q.question and
            ql.pinned == true
      ),
      set: [pinned: false]
    )

    Repo.update(QuestionLog.changeset(q, %{pinned: true}))
  end

  def delete_question(%QuestionLog{} = q), do: Repo.delete(q)

  def recent_questions(%Game{} = game, limit \\ 20) do
    Repo.all(
      from q in QuestionLog,
        where: q.game_id == ^game.id,
        order_by: [desc: q.inserted_at],
        limit: ^limit
    )
  end

  def delete_all_questions(%Game{} = game) do
    {count, _} =
      Repo.delete_all(from q in QuestionLog, where: q.game_id == ^game.id)

    {count, nil}
  end

  # ── Chunking (RAG) ──

  def chunk_document(%Document{} = doc) do
    Repo.delete_all(from c in Chunk, where: c.document_id == ^doc.id)

    chunks =
      doc.full_text
      |> split_into_chunks(500)
      |> Enum.with_index()

    # Detect section labels and cross-references per chunk
    chunks_with_meta =
      chunks
      |> Enum.map(fn {text, idx} ->
        section = detect_section_label(text)
        refs = detect_cross_references(text)
        {text, idx, section, refs}
      end)

    # Insert all chunks with metadata
    Enum.each(chunks_with_meta, fn {text, idx, section, refs} ->
      case %Chunk{}
           |> Chunk.changeset(%{
             document_id: doc.id,
             chunk_index: idx,
             content: text,
             section_label: section,
             references_section: refs
           })
           |> Repo.insert() do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          require Logger
          Logger.error("Failed to insert chunk #{idx}: #{inspect(changeset.errors)}")
      end
    end)

    # Enqueue embedding generation as Oban job (skip in test)
    unless testing?() do
      %{document_id: doc.id}
      |> RuleMaven.Workers.EmbedChunksWorker.new()
      |> Oban.insert()
    end
  end

  # Backward compat alias
  defdelegate chunk_source(source), to: __MODULE__, as: :chunk_document

  def retrieve_chunks(%Game{} = game, question, limit \\ 6) do
    retrieve_chunks_for_games([game.id], question, limit)
  end

  def retrieve_chunks_for_games(game_ids, question, limit \\ 6) when is_list(game_ids) do
    # Try semantic retrieval via pgvector
    case RuleMaven.Embed.embed(question) do
      {:ok, question_vec} ->
        chunks =
          Repo.all(
            from c in Chunk,
              join: d in Document,
              on: c.document_id == d.id,
              where:
                d.game_id in ^game_ids and d.status == "published" and
                  not is_nil(c.embedding),
              order_by:
                fragment(
                  "cosine_distance(?, ?::vector)",
                  c.embedding,
                  ^Pgvector.new(question_vec)
                ),
              limit: ^limit,
              select: %{
                id: c.id,
                content: c.content,
                section_label: c.section_label,
                references_section: c.references_section
              }
          )

        if chunks == [] do
          # Fallback: full text from all games
          texts =
            Enum.map(game_ids, fn gid ->
              game = Repo.get!(Game, gid)
              document_full_text(game)
            end)
            |> Enum.reject(&(&1 == ""))

          Enum.map(texts, &{nil, &1})
        else
          chunks
          |> pull_referenced_chunks(game_ids)
          |> Enum.map(&{nil, &1.content})
        end

      {:error, _} ->
        # Fallback to keyword overlap across all games
        keyword_retrieve_multi(game_ids, question, limit)
    end
  end

  defp keyword_retrieve_multi(game_ids, question, limit) do
    chunks =
      Repo.all(
        from c in Chunk,
          join: d in Document,
          on: c.document_id == d.id,
          where: d.game_id in ^game_ids and d.status == "published",
          select: %{
            id: c.id,
            content: c.content,
            section_label: c.section_label,
            references_section: c.references_section
          }
      )

    if chunks == [] do
      texts =
        Enum.map(game_ids, fn gid ->
          game = Repo.get!(Game, gid)
          document_full_text(game)
        end)
        |> Enum.reject(&(&1 == ""))

      Enum.map(texts, &{nil, &1})
    else
      question_words = tokenize(question)

      scored =
        chunks
        |> Enum.map(fn chunk ->
          score = relevance_score(chunk.content, question_words)
          {score, chunk}
        end)
        |> Enum.sort_by(&elem(&1, 0), :desc)
        |> Enum.take(limit)

      if Enum.all?(scored, fn {score, _} -> score == 0 end) do
        texts =
          Enum.map(game_ids, fn gid ->
            game = Repo.get!(Game, gid)
            document_full_text(game)
          end)
          |> Enum.reject(&(&1 == ""))

        Enum.map(texts, &{nil, &1})
      else
        top_chunks = Enum.map(scored, fn {_, c} -> c end)
        top_chunks |> pull_referenced_chunks(game_ids) |> Enum.map(&{nil, &1.content})
      end
    end
  end

  # ── Chunk helpers ──

  defp split_into_chunks(text, target_words) do
    paragraphs = String.split(text, ~r{\n\s*\n})

    paragraphs
    |> Enum.reduce({[], []}, fn para, {current, acc} ->
      current_words = current |> Enum.join(" ") |> word_count()

      if current_words + word_count(para) > target_words and current != [] do
        {[para], [Enum.join(current, "\n\n") | acc]}
      else
        {current ++ [para], acc}
      end
    end)
    |> then(fn {current, acc} ->
      if current != [], do: [Enum.join(current, "\n\n") | acc], else: acc
    end)
    |> Enum.reverse()
  end

  defp word_count(text), do: text |> String.split(~r/\s+/) |> length()

  defp tokenize(text) do
    stop_words =
      ~w(the a an and or but in on at to for of with by from is are was were be been being have has had do does did will would can could should may might i you he she it we they me him her us them my your his its our their this that these those)

    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 in stop_words or String.length(&1) < 2))
    |> Enum.uniq()
  end

  defp relevance_score(chunk_text, question_words) do
    chunk_words = tokenize(chunk_text)
    overlap = Enum.count(question_words, &(&1 in chunk_words))

    phrase_bonus =
      if String.contains?(
           String.downcase(chunk_text),
           String.downcase(Enum.join(question_words, " "))
         ),
         do: 5,
         else: 0

    overlap + phrase_bonus
  end

  # ── Cross-reference detection ──

  # Regex patterns for cross-references like "see Section 4.3", "see rule 7.2", "see 4.1"
  @ref_pattern ~r{(?:see|refer to|reference to|per|according to)\s+(?:Section\s+|Rule\s+|§\s*)?(\d+(?:\.\d+)*)}i

  defp detect_cross_references(text) do
    @ref_pattern
    |> Regex.scan(text)
    |> Enum.map(fn [_, ref] -> ref end)
    |> Enum.uniq()
  end

  # Section label patterns: "SECTION 4: Title", "4.1 Title:", "Section 7: Full Combat Rules", etc.
  @section_pattern_head ~r/(?:SECTION|Section|Chapter)\s+(\d+(?:\.\d+)*)/i
  @section_pattern_inline ~r/^(\d+(?:\.\d+))\s/m

  defp detect_section_label(text) do
    case Regex.run(@section_pattern_head, text) do
      [_, num] -> num
      nil -> detect_inline_section(text)
    end
  end

  defp detect_inline_section(text) do
    case Regex.run(@section_pattern_inline, text) do
      [_, num] -> num
      nil -> nil
    end
  end

  defp pull_referenced_chunks(initial_chunks, game_ids) do
    # Collect all unique section labels referenced by retrieved chunks
    referenced_labels =
      initial_chunks
      |> Enum.flat_map(&(&1.references_section || []))
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    if referenced_labels == [] do
      initial_chunks
    else
      # Fetch chunks that belong to referenced sections
      referenced_chunks =
        Repo.all(
          from c in Chunk,
            join: d in Document,
            on: c.document_id == d.id,
            where:
              d.game_id in ^game_ids and d.status == "published" and
                c.section_label in ^referenced_labels,
            select: %{
              id: c.id,
              content: c.content,
              section_label: c.section_label,
              references_section: c.references_section
            }
        )

      # Deduplicate by content (avoid adding same chunk twice)
      existing_contents = MapSet.new(initial_chunks, & &1.content)

      extra =
        Enum.reject(referenced_chunks, fn c ->
          MapSet.member?(existing_contents, c.content)
        end)

      initial_chunks ++ extra
    end
  end
end
