defmodule RuleMaven.LLM.NormalizeCache do
  @moduledoc """
  In-memory cache of normalized questions, keyed per `{game_id, downcased_raw}`.

  Question normalization runs a (cheap) LLM call on every ask to rewrite the
  question into a stable canonical form before it drives the pool lookup and
  retrieval. Repeated phrasings — common ones, suggested questions, a user
  re-asking the same text — would otherwise pay that call every time. The
  rewrite is deterministic for a given raw string, so caching it is safe.

  Only context-free questions are cached (followups resolve against the recent
  conversation, so their normalization is not a pure function of the raw text —
  the caller skips the cache for those).

  Backed by a public ETS table owned by this GenServer; `get/1` and `put/2` hit
  ETS directly. A periodic sweep drops entries past their TTL so the table can't
  grow without bound.
  """
  use GenServer

  @table :llm_normalize_cache
  @ttl_seconds 86_400
  @sweep_interval_ms 3_600_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Returns `{:ok, cleaned}` on a live hit, `:miss` otherwise."
  def get(key) do
    case lookup(key) do
      {cleaned, stored_at} ->
        if now() - stored_at <= @ttl_seconds, do: {:ok, cleaned}, else: :miss

      nil ->
        :miss
    end
  end

  @doc "Stores `cleaned` for `key`. No-op until the table exists."
  def put(key, cleaned) do
    if table_ready?() do
      :ets.insert(@table, {key, {cleaned, now()}})
    end

    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff = now() - @ttl_seconds
    # Match-delete every entry whose stored_at is older than the cutoff.
    :ets.select_delete(@table, [{{:_, {:_, :"$1"}}, [{:<, :"$1", cutoff}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp lookup(key) do
    if table_ready?() do
      case :ets.lookup(@table, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    else
      nil
    end
  end

  defp table_ready?, do: :ets.whereis(@table) != :undefined

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  defp now, do: System.system_time(:second)
end
