defmodule RuleMaven.Voices do
  @moduledoc """
  Persona voices: cached, in-character restyles of canonical answers.

  The canonical answer (the pooled, citation-bearing source of truth) is never
  modified. A voice is a *rendering* of that prose — same facts, same numbers,
  different tone. Each `(answer, voice)` restyle is generated once and cached in
  `answer_voices`, so switching between voices is free after first touch and the
  cache is shared across every viewer.

  The restyler only ever sees the already-grounded answer text — never the
  rulebook — so it cannot introduce new rules. Citations, page numbers, and the
  verdict stamp render from the canonical row and are intentionally left neutral.

  ## Global vs. per-game voices

  There are two sources of voices:

    * **Global** — the built-in `@voices` below, present on every game.
    * **Per-game** — rows in `game_voices`, *generated* from a game's own
      rulebook/theme (see `RuleMaven.Workers.VoiceSuggestionsWorker`) so the
      list feels native to the game. Generated voices only ever ADD to the
      globals; globals are always shown.

  A generated voice's id is namespaced `g:<slug>` so it can never collide with
  a global id. That namespaced id is what lands in `answer_voices.voice`.
  """

  import Ecto.Query
  alias RuleMaven.{Repo, LLM}
  alias RuleMaven.Voices.{AnswerVoice, GameVoice}

  @game_prefix "g:"

  # id => %{label, emoji, style}. "neutral" is the canonical default and is NOT
  # stored or restyled — it just shows the original answer.
  @voices [
    %{id: "neutral", label: "Plain", emoji: "📋", style: nil},
    %{
      id: "lawyer",
      label: "Rules Lawyer",
      emoji: "🧑‍⚖️",
      style:
        "a smug, hyper-precise rules lawyer. Formal, lightly pedantic, fond of phrases like \"per the rules as written\" and \"strictly speaking.\" Never rude, just insufferably correct."
    },
    %{
      id: "pirate",
      label: "Pirate",
      emoji: "🏴‍☠️",
      style:
        "a swashbuckling pirate. Nautical slang, \"arr\", \"ye\", \"matey\", \"the rulebook be sayin'\". Playful and boisterous."
    },
    %{
      id: "robot",
      label: "Robot Referee",
      emoji: "🤖",
      style:
        "a deadpan robot referee. Terse, official, monotone. Clipped sentences. Occasional \"BEEP.\" or \"RULING:\" prefix. No emotion."
    },
    %{
      id: "coach",
      label: "Hype Coach",
      emoji: "📣",
      style:
        "an over-the-top motivational sports coach. Loud, encouraging, lots of energy and short pep-talk bursts. Still delivers the exact rule."
    }
  ]

  @global_ids Enum.map(@voices, & &1.id)

  @doc "All GLOBAL voice definitions (including neutral). Game-agnostic."
  def all, do: @voices

  @doc "The selectable global persona voices (excludes neutral default)."
  def personas, do: Enum.reject(@voices, &(&1.id == "neutral"))

  @doc """
  Every voice available for a game: the globals followed by the game's own
  generated voices. Neutral stays first. `game` may be a `%Game{}` or a game id.
  """
  def for_game(game) do
    @voices ++ game_voice_defs(game_id(game))
  end

  @doc "Just the game's generated persona voices, as voice defs (id = `g:<slug>`)."
  def game_voice_defs(nil), do: []

  def game_voice_defs(game_id) do
    Repo.all(
      from gv in GameVoice,
        where: gv.game_id == ^game_id,
        order_by: [asc: gv.position, asc: gv.id],
        select: %{slug: gv.slug, label: gv.label, emoji: gv.emoji, style: gv.style}
    )
    |> Enum.map(fn gv ->
      %{id: @game_prefix <> gv.slug, label: gv.label, emoji: gv.emoji, style: gv.style}
    end)
  end

  @doc "True for a built-in global voice id (no game context needed)."
  def valid?(voice), do: voice in @global_ids

  @doc "True for any voice available on `game` (global or that game's generated)."
  def valid?(voice, game) do
    valid?(voice) or get_def(voice, game) != nil
  end

  @doc "A global voice def by id, or nil."
  def get_def(voice), do: Enum.find(@voices, &(&1.id == voice))

  @doc "A voice def by id within a game's scope (global or generated), or nil."
  def get_def(voice, game) do
    cond do
      g = get_def(voice) ->
        g

      String.starts_with?(voice, @game_prefix) ->
        Enum.find(game_voice_defs(game_id(game)), &(&1.id == voice))

      true ->
        nil
    end
  end

  @doc "Cached restyle content for one (question, voice), or nil."
  def get(question_log_id, voice) do
    Repo.one(
      from v in AnswerVoice,
        where: v.question_log_id == ^question_log_id and v.voice == ^voice,
        select: v.content
    )
  end

  @doc "Map of `voice => content` already cached for a question."
  def cached_voices(question_log_id) do
    Repo.all(
      from v in AnswerVoice,
        where: v.question_log_id == ^question_log_id,
        select: {v.voice, v.content}
    )
    |> Map.new()
  end

  @doc """
  Returns the cached restyle if present, else generates it via the LLM, stores
  it, and returns `{:ok, content}`. "neutral" returns the canonical text as-is
  without storing. Concurrent generators race-safely upsert. `game` may be a
  `%Game{}` or id and scopes which generated voices are valid.
  """
  def restyle(_question_log_id, "neutral", canonical, _game), do: {:ok, canonical}

  def restyle(question_log_id, voice, canonical, game) do
    voice_def = get_def(voice, game)

    cond do
      voice_def == nil ->
        {:error, :unknown_voice}

      cached = get(question_log_id, voice) ->
        {:ok, cached}

      true ->
        with {:ok, styled} <- generate(voice_def, canonical, game_name(game)) do
          store(question_log_id, voice, styled)
          {:ok, styled}
        end
    end
  end

  defp generate(%{id: id, style: style}, canonical, game_name) do
    system = RuleMaven.Prompts.template("voice_restyle_system")
    prompt = RuleMaven.Prompts.render("voice_restyle", %{style: style, answer: canonical})

    LLM.chat(prompt, "voice_#{id}_#{game_name}", system: system, max_tokens: 700)
  end

  defp store(question_log_id, voice, content) do
    %AnswerVoice{}
    |> AnswerVoice.changeset(%{
      question_log_id: question_log_id,
      voice: voice,
      content: content
    })
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:question_log_id, :voice]
    )
  end

  @doc """
  Replaces a game's generated voices with `voices` (a list of
  `%{slug, label, emoji, style}`), keeping slugs stable so already-paid restyle
  caches survive. Only voices whose style actually changed (or that vanished)
  have their cached restyles dropped; everything else stays free.
  """
  def replace_generated(game_id, voices) do
    existing = Repo.all(from gv in GameVoice, where: gv.game_id == ^game_id)
    by_slug = Map.new(existing, &{&1.slug, &1})
    new_slugs = MapSet.new(voices, & &1.slug)

    # Drop generated voices that no longer appear, clearing their restyle cache.
    Enum.each(existing, fn gv ->
      unless MapSet.member?(new_slugs, gv.slug) do
        clear_for_voice(game_id, @game_prefix <> gv.slug)
        Repo.delete(gv)
      end
    end)

    voices
    |> Enum.with_index()
    |> Enum.each(fn {v, idx} ->
      attrs = %{
        game_id: game_id,
        slug: v.slug,
        label: v.label,
        emoji: v.emoji,
        style: v.style,
        source: "generated",
        position: idx
      }

      case Map.get(by_slug, v.slug) do
        nil ->
          %GameVoice{} |> GameVoice.changeset(attrs) |> Repo.insert()

        %GameVoice{style: old_style} = row ->
          # A style change invalidates any restyles already cached for this voice.
          if old_style != v.style, do: clear_for_voice(game_id, @game_prefix <> v.slug)
          row |> GameVoice.changeset(attrs) |> Repo.update()
      end
    end)

    :ok
  end

  @doc """
  Drops all cached restyles for a game's answers. Called when rulebook content
  changes (alongside pool invalidation) so stale-voiced answers regenerate.
  """
  def clear_for_game(game_id) do
    from(v in AnswerVoice,
      join: q in RuleMaven.Games.QuestionLog,
      on: q.id == v.question_log_id,
      where: q.game_id == ^game_id
    )
    |> Repo.delete_all()
  end

  @doc "Drops cached restyles of one voice across a game's answers."
  def clear_for_voice(game_id, voice) do
    from(v in AnswerVoice,
      join: q in RuleMaven.Games.QuestionLog,
      on: q.id == v.question_log_id,
      where: q.game_id == ^game_id and v.voice == ^voice
    )
    |> Repo.delete_all()
  end

  @doc "Drops cached restyles for one answer (e.g. on regenerate)."
  def clear_for_question(question_log_id) do
    Repo.delete_all(from v in AnswerVoice, where: v.question_log_id == ^question_log_id)
  end

  defp game_id(%{id: id}), do: id
  defp game_id(id) when is_integer(id), do: id
  defp game_id(id) when is_binary(id), do: id
  defp game_id(_), do: nil

  defp game_name(%{name: name}), do: name
  defp game_name(_), do: ""
end
