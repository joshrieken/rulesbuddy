defmodule RuleMaven.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias RuleMaven.Repo

  alias RuleMaven.Games.Game
  alias RuleMaven.Games.QuestionLog
  alias RuleMaven.Games.RulebookSource

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete_all(from r in RulebookSource, where: r.game_id == ^game.id)
    Repo.delete_all(from q in QuestionLog, where: q.game_id == ^game.id)
    Repo.delete(game)
  end

  @doc """
  Deletes all games and associated data. Returns {count, nil}.
  """
  def delete_all_games do
    Repo.delete_all(RulebookSource)
    Repo.delete_all(QuestionLog)
    {count, _} = Repo.delete_all(Game)
    {count, nil}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  # --- Rulebook Sources ---

  @doc """
  Returns the list of rulebook sources for a game.
  """
  def list_rulebook_sources(%Game{} = game) do
    Repo.all(from r in RulebookSource, where: r.game_id == ^game.id)
  end

  @doc """
  Creates a rulebook source.
  """
  def create_rulebook_source(attrs) do
    result =
      %RulebookSource{}
      |> RulebookSource.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, source} ->
        chunk_source(source)
        {:ok, source}

      error ->
        error
    end
  end

  @doc """
  Deletes a rulebook source.
  """
  def delete_rulebook_source(%RulebookSource{} = source) do
    Repo.delete(source)
  end

  @doc """
  Returns the full concatenated rulebook text for a game.
  """
  def rulebook_text(%Game{} = game) do
    game
    |> list_rulebook_sources()
    |> Enum.map_join("\n\n", & &1.full_text)
  end

  # --- Question Log ---

  @doc """
  Logs a question and answer.
  """
  def log_question(attrs) do
    %QuestionLog{}
    |> QuestionLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the count of questions logged for a game.
  """
  def question_count(%Game{} = game) do
    Repo.aggregate(from(q in QuestionLog, where: q.game_id == ^game.id), :count)
  end

  @doc """
  Returns the count of questions asked by a user since a given datetime.
  """
  def recent_question_count(user_id, since) do
    Repo.aggregate(
      from(q in QuestionLog, where: q.user_id == ^user_id and q.inserted_at >= ^since),
      :count
    )
  end

  @doc """
  Returns recent questions grouped by question text, with the pinned one
  first (or most recent if none pinned).
  """
  def grouped_questions(%Game{} = game) do
    game
    |> recent_questions(100)
    |> Enum.group_by(&String.downcase(String.trim(&1.question)))
    |> Enum.map(fn {_key, entries} ->
      # Sort: pinned first, then by most recent
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

  @doc """
  Pins a question log entry and unpins others with the same question.
  """
  def pin_question(%QuestionLog{} = q) do
    # Unpin all with same question
    Repo.update_all(
      from(ql in QuestionLog,
        where: ql.game_id == ^q.game_id and ql.question == ^q.question and ql.pinned == true
      ),
      set: [pinned: false]
    )

    Repo.update(QuestionLog.changeset(q, %{pinned: true}))
  end

  @doc """
  Deletes a single question log entry.
  """
  def delete_question(%QuestionLog{} = q) do
    Repo.delete(q)
  end

  @doc """
  Returns the recent questions for a game.
  """
  def recent_questions(%Game{} = game, limit \\ 20) do
    Repo.all(
      from q in QuestionLog,
        where: q.game_id == ^game.id,
        order_by: [desc: q.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Deletes all question logs for a game. Returns `{count, nil}` where count
  is the number of deleted records.
  """
  def delete_all_questions(%Game{} = game) do
    {count, _} =
      Repo.delete_all(
        from q in QuestionLog,
          where: q.game_id == ^game.id
      )

    {count, nil}
  end

  # --- Rulebook Chunks (RAG) ---

  alias RuleMaven.Games.RulebookChunk

  @doc """
  Chunks the full_text of a source into ~500 token sections and stores them.
  Deletes old chunks for this source first.
  """
  def chunk_source(%RulebookSource{} = source) do
    Repo.delete_all(from c in RulebookChunk, where: c.source_id == ^source.id)

    source.full_text
    |> split_into_chunks(500)
    |> Enum.with_index()
    |> Enum.each(fn {chunk, idx} ->
      %RulebookChunk{}
      |> RulebookChunk.changeset(%{
        game_id: source.game_id,
        source_id: source.id,
        chunk_index: idx,
        content: chunk
      })
      |> Repo.insert!()
    end)
  end

  @doc """
  Retrieves top-N most relevant chunks for a question using keyword overlap.
  """
  def retrieve_chunks(%Game{} = game, question, limit \\ 6) do
    chunks = Repo.all(from c in RulebookChunk, where: c.game_id == ^game.id)

    if chunks == [] do
      # Fallback: return full rulebook text as single chunk
      [{nil, rulebook_text(game)}]
    else
      question_words = tokenize(question)

      chunks
      |> Enum.map(fn chunk ->
        score = relevance_score(chunk.content, question_words)
        {score, chunk.content}
      end)
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.take(limit)
      |> Enum.reject(fn {score, _} -> score == 0 end)
      |> case do
        [] -> [{nil, rulebook_text(game)}]
        results -> results
      end
    end
  end

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
    stop_words = ~w(the a an and or but in on at to for of with by from is are was were be been being have has had do does did will would can could should may might i you he she it we they me him her us them my your his its our their this that these those)

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
    # Bonus for exact phrase matches
    phrase_bonus = if String.contains?(String.downcase(chunk_text), String.downcase(Enum.join(question_words, " "))), do: 5, else: 0
    overlap + phrase_bonus
  end
end
