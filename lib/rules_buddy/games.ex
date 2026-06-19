defmodule RulesBuddy.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias RulesBuddy.Repo

  alias RulesBuddy.Games.Game
  alias RulesBuddy.Games.QuestionLog
  alias RulesBuddy.Games.RulebookSource

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
    Repo.delete(game)
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
    %RulebookSource{}
    |> RulebookSource.changeset(attrs)
    |> Repo.insert()
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
end
