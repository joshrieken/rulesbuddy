# LLM Savings Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record token/cost savings from cache hits, provider prompt caching, and cheap-model routing in a dedicated `llm_savings` ledger, surfaced in the admin Usage dashboard.

**Architecture:** A new append-only `llm_savings` table + `RuleMaven.LLM.Savings` module collects three savings kinds. Producers are wired at single chokepoints: `ask/5`'s pool-hit branch (cache_hit) and `do_request_real`'s success branch (prompt_cache + cheap_route). Amounts come from `RuleMaven.LLM.Pricing` (real for prompt_cache, estimated from rolling `LLM.Log` history for cache_hit, counterfactual diff for cheap_route). The admin Usage LiveView gains a Savings panel.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto/Postgres, Req.

## Global Constraints

- Savings writes are **best-effort and non-blocking**: a ledger failure must never raise into or block the request/answer path. Wrap inserts, log-and-swallow.
- `cheap_route` is **counterfactual** and is **NEVER summed into the headline savings total**; show it as a separate/secondary stat labeled accordingly.
- Only `prompt_cache` is a real provider discount; `cache_hit` is a real avoidance with an **estimated** amount. Dashboard labels estimate-based figures "estimated".
- Dollar amounts via `RuleMaven.LLM.Pricing` only (estimates for budgeting, not billing).
- Follow existing patterns: migrations under `priv/repo/migrations`, schemas under `lib/rule_maven/llm/`, admin dashboard is `RuleMavenWeb.AdminLive.Usage`.
- Capability gate for the dashboard: `Users.can?(user, :admin)` (already in place).

---

### Task 1: `llm_savings` table + `LLM.Savings` schema + `record/2`

**Files:**
- Create: `priv/repo/migrations/20260629060000_create_llm_savings.exs`
- Create: `lib/rule_maven/llm/savings.ex`
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Produces:
  - `RuleMaven.LLM.Savings` Ecto schema, table `llm_savings`, fields: `kind` (string), `operation` (string), `estimated_tokens` (integer), `estimated_usd` (float), `model` (string), `game_id` (integer), `user_id` (integer), `inserted_at` (utc_datetime).
  - `RuleMaven.LLM.Savings.record(kind :: String.t(), attrs :: map()) :: :ok` — best-effort insert, always returns `:ok`.

- [ ] **Step 1: Write the migration**

```elixir
defmodule RuleMaven.Repo.Migrations.CreateLlmSavings do
  use Ecto.Migration

  def change do
    create table(:llm_savings) do
      add :kind, :string, null: false
      add :operation, :string
      add :estimated_tokens, :integer, default: 0
      add :estimated_usd, :float, default: 0.0
      add :model, :string
      add :game_id, references(:games, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:llm_savings, [:inserted_at])
    create index(:llm_savings, [:kind, :inserted_at])
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `mix ecto.migrate`
Expected: creates `llm_savings`, no error.

- [ ] **Step 3: Write the failing test**

```elixir
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
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`RuleMaven.LLM.Savings` undefined).

- [ ] **Step 5: Write the schema + `record/2`**

```elixir
defmodule RuleMaven.LLM.Savings do
  @moduledoc """
  Append-only ledger of estimated/real LLM cost savings.

  Three kinds:
    * "cache_hit"    — a pool hit avoided a whole LLM ask. Real avoidance, the
                       amount is estimated from recent real usage.
    * "prompt_cache" — provider billed cached input tokens at a lower rate. Real
                       discount.
    * "cheap_route"  — an op ran on a cheap model instead of the answer model.
                       Counterfactual; never summed into the headline total.

  Writes are best-effort: a ledger failure must never break the request path.
  """
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias RuleMaven.Repo

  @kinds ~w(cache_hit prompt_cache cheap_route)

  schema "llm_savings" do
    field :kind, :string
    field :operation, :string
    field :estimated_tokens, :integer, default: 0
    field :estimated_usd, :float, default: 0.0
    field :model, :string
    field :game_id, :id
    field :user_id, :id

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc "Best-effort insert of a savings row. Always returns :ok."
  def record(kind, attrs) when kind in @kinds do
    attrs = Map.put(attrs, :kind, kind)

    %__MODULE__{}
    |> cast(attrs, [:kind, :operation, :estimated_tokens, :estimated_usd, :model, :game_id, :user_id])
    |> validate_required([:kind])
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, cs} -> Logger.warning("Savings.record failed: #{inspect(cs.errors)}"); :ok
    end
  rescue
    e -> Logger.warning("Savings.record raised: #{inspect(e)}"); :ok
  end

  def record(_kind, _attrs), do: :ok
end
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add priv/repo/migrations/20260629060000_create_llm_savings.exs lib/rule_maven/llm/savings.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: llm_savings ledger table + Savings.record"
```

---

### Task 2: Pricing — cached-input rate

**Files:**
- Modify: `lib/rule_maven/llm/pricing.ex`
- Test: `test/rule_maven/llm_cost_test.exs` (add a `describe` block)

**Interfaces:**
- Consumes: `RuleMaven.LLM.Pricing.rate/1`, `cost/3` (existing).
- Produces:
  - `RuleMaven.LLM.Pricing.cached_savings(model :: String.t(), cached_tokens :: integer()) :: float()` — USD saved by `cached_tokens` of input being billed at the cached rate instead of the full input rate.

- [ ] **Step 1: Write the failing test**

Append to `test/rule_maven/llm_cost_test.exs`, inside the module:

```elixir
  describe "cached_savings/2" do
    test "saves the discount between full and cached input rate" do
      # gemini-2.5-flash input rate is 0.30 / Mtok. Cached billed at 25% of that,
      # so the saving is 75% of the full input cost of the cached tokens.
      saved = RuleMaven.LLM.Pricing.cached_savings("google/gemini-2.5-flash", 1_000_000)
      assert_in_delta saved, 0.30 * 0.75, 0.0001
    end

    test "zero cached tokens saves nothing" do
      assert RuleMaven.LLM.Pricing.cached_savings("gemini-2.5-flash", 0) == 0.0
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_cost_test.exs`
Expected: FAIL (`cached_savings/2` undefined).

- [ ] **Step 3: Implement `cached_savings/2`**

Add to `lib/rule_maven/llm/pricing.ex` (after `cost/3`):

```elixir
  # Fraction of the full input rate that cached input tokens are billed at.
  # Gemini implicit caching bills cached input at ~25% of the input rate; this
  # is an estimate for the savings dashboard, refine per provider as needed.
  @cached_rate_fraction 0.25

  @doc """
  USD saved by `cached_tokens` input tokens being billed at the cached rate
  instead of the full input rate, for `model`.
  """
  def cached_savings(_model, cached_tokens) when cached_tokens in [nil, 0], do: 0.0

  def cached_savings(model, cached_tokens) do
    {in_rate, _out} = rate(model)
    full = cached_tokens / 1_000_000 * in_rate
    full * (1.0 - @cached_rate_fraction)
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_cost_test.exs`
Expected: PASS (existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add lib/rule_maven/llm/pricing.ex test/rule_maven/llm_cost_test.exs
git commit -m "feat: Pricing.cached_savings for prompt-cache discount"
```

---

### Task 3: Avoided-call estimator

**Files:**
- Modify: `lib/rule_maven/llm/savings.ex`
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Consumes: `RuleMaven.LLM.Log` rows, `RuleMaven.LLM.Pricing.cost/3`, `RuleMaven.LLM.model/0`.
- Produces:
  - `RuleMaven.LLM.Savings.estimate_avoided(operation :: String.t(), game_id :: integer() | nil) :: %{tokens: integer(), usd: float(), model: String.t()}` — average prompt+completion tokens of the last 50 successful same-`operation` `LLM.Log` rows (preferring `game_id`, widening to all games if fewer than 3), priced via `Pricing.cost/3` at the current default model; constant fallback when no history.

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/llm_savings_test.exs`:

```elixir
  describe "estimate_avoided/2" do
    alias RuleMaven.LLM
    alias RuleMaven.Repo

    defp log!(op, p, c) do
      Repo.insert!(%LLM.Log{
        provider: "test", model: "google/gemini-2.5-flash", operation: op,
        prompt_tokens: p, completion_tokens: c, total_tokens: p + c, success: true
      })
    end

    test "averages recent same-operation history" do
      log!("ask", 1000, 100)
      log!("ask", 3000, 300)
      est = Savings.estimate_avoided("ask", nil)
      assert est.tokens == 2200
      assert est.usd > 0.0
    end

    test "falls back to a constant when there is no history" do
      est = Savings.estimate_avoided("ask", nil)
      assert est.tokens > 0
      assert est.usd > 0.0
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`estimate_avoided/2` undefined).

- [ ] **Step 3: Implement `estimate_avoided/2`**

Add to `lib/rule_maven/llm/savings.ex`:

```elixir
  import Ecto.Query

  # Cold-start fallback per operation: {prompt_tokens, completion_tokens}.
  @fallback_tokens %{"ask" => {4000, 300}}
  @default_fallback {2000, 200}
  @window 50
  @min_same_game 3

  @doc """
  Estimates the tokens/USD a now-avoided call of `operation` would have cost,
  from the average of recent real `LLM.Log` rows (preferring `game_id`). Falls
  back to a per-operation constant when there is no usable history.
  """
  def estimate_avoided(operation, game_id) do
    model = RuleMaven.LLM.model()
    rows = recent_logs(operation, game_id)

    rows = if length(rows) < @min_same_game, do: recent_logs(operation, nil), else: rows

    {p, c} =
      case rows do
        [] ->
          Map.get(@fallback_tokens, operation, @default_fallback)

        _ ->
          {avg(rows, & &1.prompt_tokens), avg(rows, & &1.completion_tokens)}
      end

    %{tokens: p + c, usd: RuleMaven.LLM.Pricing.cost(model, p, c), model: model}
  end

  defp recent_logs(operation, game_id) do
    base =
      from l in RuleMaven.LLM.Log,
        where: l.operation == ^operation and l.success == true,
        order_by: [desc: l.inserted_at],
        limit: @window

    base = if game_id, do: where(base, [l], l.game_id == ^game_id), else: base
    Repo.all(base)
  end

  defp avg([], _fun), do: 0
  defp avg(rows, fun) do
    vals = rows |> Enum.map(fun) |> Enum.map(&(&1 || 0))
    div(Enum.sum(vals), length(vals))
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/rule_maven/llm/savings.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: rolling-history estimator for avoided-call savings"
```

---

### Task 4: cache_hit producer — wire into `ask/5` pool hit

**Files:**
- Modify: `lib/rule_maven/llm/savings.ex` (add `record_cache_hit/3`)
- Modify: `lib/rule_maven/llm.ex` (pool-hit branch of `ask/5`)
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Consumes: `estimate_avoided/2`, `record/2`.
- Produces:
  - `RuleMaven.LLM.Savings.record_cache_hit(operation, game_id, user_id) :: :ok` — estimates an avoided call and writes a `cache_hit` row.

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/llm_savings_test.exs`:

```elixir
  describe "record_cache_hit/3" do
    alias RuleMaven.Repo

    test "writes a cache_hit row using the estimator" do
      assert :ok = Savings.record_cache_hit("ask", nil, nil)
      row = Repo.one(from s in Savings, where: s.kind == "cache_hit")
      assert row.operation == "ask"
      assert row.estimated_tokens > 0
      assert row.estimated_usd > 0.0
    end
  end
```

(Add `import Ecto.Query` at the top of the test module if not already present.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`record_cache_hit/3` undefined).

- [ ] **Step 3: Implement `record_cache_hit/3`**

Add to `lib/rule_maven/llm/savings.ex`:

```elixir
  @doc "Estimates and records the savings from a cache/pool hit avoiding a call."
  def record_cache_hit(operation, game_id, user_id) do
    est = estimate_avoided(operation, game_id)

    record("cache_hit", %{
      operation: operation,
      estimated_tokens: est.tokens,
      estimated_usd: est.usd,
      model: est.model,
      game_id: game_id,
      user_id: user_id
    })
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS.

- [ ] **Step 5: Wire into `ask/5`'s pool-hit branch**

In `lib/rule_maven/llm.ex`, the `pool_hit ->` branch returns the cached answer map. Immediately before that `{:ok, %{...}}` return, add the recording call. Locate:

```elixir
      pool_hit ->
        {row, tier} = pool_hit
```

Insert right after that line:

```elixir
        RuleMaven.LLM.Savings.record_cache_hit("ask", game.id, opts[:user_id])
```

- [ ] **Step 6: Run the existing LLM/pool tests to confirm no regression**

Run: `mix test test/rule_maven/llm_test.exs test/rule_maven/games_pool_invalidation_test.exs`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/rule_maven/llm/savings.ex lib/rule_maven/llm.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: record cache_hit savings on pool hits"
```

---

### Task 5: prompt_cache producer — capture cached tokens + record real discount

**Files:**
- Modify: `lib/rule_maven/llm.ex` (`extract_usage/1`, `do_request_real/3`, new `record_call_savings/3`)
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Consumes: `Pricing.cached_savings/2`, `Savings.record/2`.
- Produces:
  - Extended `extract_usage/1` return map now includes `:cached` (integer, may be 0).
  - `RuleMaven.LLM.record_call_savings(actual_model :: String.t(), opts :: keyword(), usage :: map() | nil) :: :ok` — records `prompt_cache` (and, in Task 6, `cheap_route`) from a completed call.

> **Open item (pin now):** Confirm the OpenRouter/Gemini usage key for cached prompt tokens against a live response or current docs before trusting it. This task reads `prompt_tokens_details.cached_tokens` (OpenAI-compatible shape OpenRouter forwards). If the live field differs, adjust the match in Step 3 only — the rest of the task is unaffected. When no cached field is present, `:cached` is 0 and no `prompt_cache` row is written.

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/llm_savings_test.exs`:

```elixir
  describe "record_call_savings/3 (prompt_cache)" do
    alias RuleMaven.{LLM, Repo}

    test "records a prompt_cache row when cached tokens are present" do
      usage = %{prompt: 5000, completion: 200, total: 5200, cached: 4000}
      assert :ok = LLM.record_call_savings("google/gemini-2.5-flash", [operation: "ask", game_id: nil], usage)

      row = Repo.one(from s in Savings, where: s.kind == "prompt_cache")
      assert row.estimated_tokens == 4000
      assert row.estimated_usd > 0.0
    end

    test "no prompt_cache row when there are no cached tokens" do
      usage = %{prompt: 5000, completion: 200, total: 5200, cached: 0}
      assert :ok = LLM.record_call_savings("google/gemini-2.5-flash", [operation: "ask"], usage)
      assert Repo.one(from s in Savings, where: s.kind == "prompt_cache") == nil
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`record_call_savings/3` undefined).

- [ ] **Step 3: Extend `extract_usage/1` to read cached tokens**

In `lib/rule_maven/llm.ex`, replace `extract_usage/1`:

```elixir
  defp extract_usage(body) do
    case body do
      %{"usage" => %{"prompt_tokens" => p, "completion_tokens" => c, "total_tokens" => t} = u} ->
        %{prompt: p, completion: c, total: t, cached: cached_tokens(u)}

      _ ->
        nil
    end
  end

  # Provider-reported cached prompt tokens, OpenAI-compatible shape OpenRouter
  # forwards. Tolerates the field being absent (other providers) → 0.
  defp cached_tokens(%{"prompt_tokens_details" => %{"cached_tokens" => n}}) when is_integer(n), do: n
  defp cached_tokens(%{"cached_tokens" => n}) when is_integer(n), do: n
  defp cached_tokens(_), do: 0
```

- [ ] **Step 4: Add `record_call_savings/3` (prompt_cache only for now)**

Add to `lib/rule_maven/llm.ex` (public, so tests can call it):

```elixir
  @doc false
  # Records non-call-avoidance savings from a completed LLM call: the real
  # prompt-cache discount (and cheap-route, added in a later task). Best-effort.
  def record_call_savings(actual_model, opts, usage)

  def record_call_savings(actual_model, opts, %{cached: cached} = _usage) when is_integer(cached) and cached > 0 do
    RuleMaven.LLM.Savings.record("prompt_cache", %{
      operation: opts[:operation] || "unknown",
      estimated_tokens: cached,
      estimated_usd: RuleMaven.LLM.Pricing.cached_savings(actual_model, cached),
      model: actual_model,
      game_id: opts[:game_id],
      user_id: opts[:user_id]
    })

    :ok
  end

  def record_call_savings(_actual_model, _opts, _usage), do: :ok
```

- [ ] **Step 5: Call it from `do_request_real`'s success branch**

In `lib/rule_maven/llm.ex`, the 200 branch currently reads:

```elixir
        {:ok, %{status: 200, body: response_body}} ->
          duration = System.monotonic_time(:millisecond) - start
          usage = extract_usage(response_body)
          log_llm(provider_name, model_name, opts, usage, duration, true, nil)
          parse_response(response_body)
```

Replace it with (note `actual_model` — the model the body actually requested, not the default):

```elixir
        {:ok, %{status: 200, body: response_body}} ->
          duration = System.monotonic_time(:millisecond) - start
          usage = extract_usage(response_body)
          actual_model = body[:model] || model_name
          log_llm(provider_name, actual_model, opts, usage, duration, true, nil)
          record_call_savings(actual_model, opts, usage)
          parse_response(response_body)
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS.

- [ ] **Step 7: Run the LLM cost test to confirm logging still works**

Run: `mix test test/rule_maven/llm_cost_test.exs test/rule_maven/llm_test.exs`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/rule_maven/llm.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: record real prompt-cache savings from provider usage"
```

---

### Task 6: cheap_route producer + cheap-model routing

**Files:**
- Modify: `lib/rule_maven/llm.ex` (`model/1` add `:cheap`, extend `record_call_savings/3`, route cheap ops)
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Consumes: `Pricing.cost/3`, `Savings.record/2`, `model/0`.
- Produces:
  - `RuleMaven.LLM.model(:cheap) :: String.t()` — `llm_cheap_model_<provider>` setting, else `model(:cleanup)`.
  - `record_call_savings/3` additionally writes a `cheap_route` row when the call ran on `model(:cheap)` and that differs from `model(:default)`.

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/llm_savings_test.exs`:

```elixir
  describe "record_call_savings/3 (cheap_route)" do
    alias RuleMaven.{LLM, Settings, Repo}

    test "records cheap_route when the call ran on the cheap model" do
      Settings.put("llm_cheap_model_openrouter", "google/gemini-2.0-flash")
      cheap = LLM.model(:cheap)
      refute cheap == LLM.model(:default)

      usage = %{prompt: 10_000, completion: 500, total: 10_500, cached: 0}
      assert :ok = LLM.record_call_savings(cheap, [operation: "suggest_questions"], usage)

      row = Repo.one(from s in Savings, where: s.kind == "cheap_route")
      assert row.operation == "suggest_questions"
      # default (gemini-2.5-flash) costs more than cheap (gemini-2.0-flash):
      assert row.estimated_usd > 0.0
    end

    test "no cheap_route when the call ran on the default model" do
      usage = %{prompt: 10_000, completion: 500, total: 10_500, cached: 0}
      assert :ok = LLM.record_call_savings(LLM.model(:default), [operation: "ask"], usage)
      assert Repo.one(from s in Savings, where: s.kind == "cheap_route") == nil
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`model(:cheap)` undefined / no cheap_route row).

- [ ] **Step 3: Add `model(:cheap)`**

In `lib/rule_maven/llm.ex`, add a clause next to `model(:cleanup)`:

```elixir
  def model(:cheap) do
    case RuleMaven.Settings.get("llm_cheap_model_#{provider()}") do
      m when is_binary(m) and m != "" -> m
      _ -> model(:cleanup)
    end
  end
```

- [ ] **Step 4: Extend `record_call_savings/3` with a cheap_route clause**

In `lib/rule_maven/llm.ex`, change the prompt_cache clause so it also handles cheap_route, by adding a dedicated tail before the no-op catch-all. Replace the whole `record_call_savings/3` definition added in Task 5 with:

```elixir
  @doc false
  # Records non-call-avoidance savings from a completed LLM call:
  #   * prompt_cache — real provider discount on cached input tokens
  #   * cheap_route  — counterfactual: ran on the cheap model, not the answer model
  # Best-effort; both may fire for one call.
  def record_call_savings(actual_model, opts, usage) do
    maybe_record_prompt_cache(actual_model, opts, usage)
    maybe_record_cheap_route(actual_model, opts, usage)
    :ok
  end

  defp maybe_record_prompt_cache(actual_model, opts, %{cached: cached}) when is_integer(cached) and cached > 0 do
    RuleMaven.LLM.Savings.record("prompt_cache", %{
      operation: opts[:operation] || "unknown",
      estimated_tokens: cached,
      estimated_usd: RuleMaven.LLM.Pricing.cached_savings(actual_model, cached),
      model: actual_model,
      game_id: opts[:game_id],
      user_id: opts[:user_id]
    })
  end

  defp maybe_record_prompt_cache(_m, _o, _u), do: :ok

  defp maybe_record_cheap_route(actual_model, opts, %{prompt: p, completion: c}) do
    default = model(:default)

    if actual_model == model(:cheap) and actual_model != default do
      saved = RuleMaven.LLM.Pricing.cost(default, p, c) - RuleMaven.LLM.Pricing.cost(actual_model, p, c)

      RuleMaven.LLM.Savings.record("cheap_route", %{
        operation: opts[:operation] || "unknown",
        estimated_tokens: (p || 0) + (c || 0),
        estimated_usd: max(saved, 0.0),
        model: actual_model,
        game_id: opts[:game_id],
        user_id: opts[:user_id]
      })
    end

    :ok
  end

  defp maybe_record_cheap_route(_m, _o, _u), do: :ok
```

- [ ] **Step 5: Route the cheap ops onto the cheap model**

These call sites should run on `model(:cheap)` so the saving is realized and recorded. Update each `chat/...` call to pass `model: model(:cheap)` (replacing any existing `model:` arg) and an explicit `operation:`.

In `lib/rule_maven/llm.ex`:
- `suggest_questions` (the `chat(prompt, "suggest_questions", ...)` call ~line 1053): add/replace `model: model(:cheap), operation: "suggest_questions"`.
- `did_you_know` (the `chat(prompt, "did_you_know", ...)` call ~line 1105): add/replace `model: model(:cheap), operation: "did_you_know"`.
- `did_you_know_verify` (~line 1154): add/replace `model: model(:cheap), operation: "did_you_know_verify"`.

For `normalize` (the `chat(user, "normalize_question", ...)` call in `do_normalize/3`): change `model: model(:cleanup)` to `model: model(:cheap)`.

Example (suggest_questions), before:

```elixir
    case chat(prompt, "suggest_questions",
           system: RuleMaven.Prompts.template("suggest_questions_system"),
           ...
         ) do
```

after — ensure these two opts are present:

```elixir
    case chat(prompt, "suggest_questions",
           system: RuleMaven.Prompts.template("suggest_questions_system"),
           model: model(:cheap),
           operation: "suggest_questions",
           ...
         ) do
```

(Leave the rest of each call's opts unchanged.)

- [ ] **Step 6: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS.

- [ ] **Step 7: Run the broader LLM suite for regressions**

Run: `mix test test/rule_maven/llm_test.exs test/rule_maven/llm_cost_test.exs test/rule_maven/workers/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/rule_maven/llm.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: cheap-model routing + cheap_route counterfactual savings"
```

---

### Task 7: Savings roll-up queries

**Files:**
- Modify: `lib/rule_maven/llm/savings.ex`
- Test: `test/rule_maven/llm_savings_test.exs`

**Interfaces:**
- Produces:
  - `RuleMaven.LLM.Savings.summary(days :: integer()) :: %{days: integer(), headline_usd: float(), headline_tokens: integer(), by_kind: [%{kind: String.t(), tokens: integer(), usd: float()}]}` — `headline_*` sum only `cache_hit` + `prompt_cache`; `by_kind` includes all three.

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/llm_savings_test.exs`:

```elixir
  describe "summary/1" do
    test "headline excludes cheap_route" do
      Savings.record("cache_hit", %{operation: "ask", estimated_tokens: 100, estimated_usd: 0.10})
      Savings.record("prompt_cache", %{operation: "ask", estimated_tokens: 50, estimated_usd: 0.05})
      Savings.record("cheap_route", %{operation: "suggest_questions", estimated_tokens: 999, estimated_usd: 9.99})

      s = Savings.summary(30)
      assert_in_delta s.headline_usd, 0.15, 0.0001
      assert s.headline_tokens == 150
      kinds = Map.new(s.by_kind, &{&1.kind, &1})
      assert kinds["cheap_route"].usd == 9.99
      refute Map.has_key?(kinds, "cheap_route") and s.headline_usd > 0.15
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: FAIL (`summary/1` undefined).

- [ ] **Step 3: Implement `summary/1`**

Add to `lib/rule_maven/llm/savings.ex`:

```elixir
  @headline_kinds ~w(cache_hit prompt_cache)

  @doc """
  Savings roll-up for the last `days` days. `headline_*` count only real-
  avoidance/real-discount kinds (cache_hit, prompt_cache); cheap_route is
  reported in `by_kind` but excluded from the headline.
  """
  def summary(days \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    by_kind =
      Repo.all(
        from s in __MODULE__,
          where: s.inserted_at >= ^since,
          group_by: s.kind,
          select: {s.kind, sum(s.estimated_tokens), sum(s.estimated_usd)}
      )
      |> Enum.map(fn {k, t, u} -> %{kind: k, tokens: t || 0, usd: (u || 0.0) * 1.0} end)

    headline = Enum.filter(by_kind, &(&1.kind in @headline_kinds))

    %{
      days: days,
      headline_usd: Enum.reduce(headline, 0.0, &(&1.usd + &2)),
      headline_tokens: Enum.reduce(headline, 0, &(&1.tokens + &2)),
      by_kind: by_kind
    }
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/rule_maven/llm_savings_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/rule_maven/llm/savings.ex test/rule_maven/llm_savings_test.exs
git commit -m "feat: Savings.summary roll-up (headline excludes cheap_route)"
```

---

### Task 8: Dashboard Savings panel

**Files:**
- Modify: `lib/rule_maven_web/live/admin_live/usage.ex`

**Interfaces:**
- Consumes: `RuleMaven.LLM.Savings.summary/1`.

- [ ] **Step 1: Load the summary in `load/1`**

In `lib/rule_maven_web/live/admin_live/usage.ex`, extend `load/1`:

```elixir
  defp load(socket) do
    days = socket.assigns.days
    by_user = LLM.cost_by_user(days)

    assign(socket,
      stats: LLM.stats(days),
      by_user: by_user,
      total_cost: Enum.reduce(by_user, 0.0, &(&1.cost + &2)),
      savings: RuleMaven.LLM.Savings.summary(days)
    )
  end
```

- [ ] **Step 2: Add the Savings panel to `render/1`**

In the same file, immediately after the top stat grid (the `<div ...>` containing the `<.stat .../>` items ending before the cost-cap form), insert:

```heex
      <div style="background:var(--bg-surface);border:1px solid var(--border);border-radius:0.5rem;padding:0.75rem 1rem;margin-bottom:1.25rem">
        <h2 style="font-size:1rem;font-weight:700;margin-bottom:0.5rem">Estimated savings</h2>
        <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(9rem,1fr));gap:0.6rem">
          <.stat label="Saved (est.)" value={"$#{fmt_cost(@savings.headline_usd)}"} />
          <.stat label="Saved tokens" value={fmt_int(@savings.headline_tokens)} />
          <%= for k <- @savings.by_kind, k.kind in ["cache_hit", "prompt_cache"] do %>
            <.stat label={savings_label(k.kind)} value={"$#{fmt_cost(k.usd)}"} />
          <% end %>
        </div>
        <%= for k <- @savings.by_kind, k.kind == "cheap_route" do %>
          <p style="margin-top:0.5rem;font-size:0.72rem;color:var(--text-muted)">
            Cheap-model routing (counterfactual, not in total): ${fmt_cost(k.usd)} vs running on the answer model.
          </p>
        <% end %>
      </div>
```

- [ ] **Step 3: Add the `savings_label/1` helper**

At the bottom of the module (near `fmt_cost`/`fmt_int`), add:

```elixir
  defp savings_label("cache_hit"), do: "Cache hits (est.)"
  defp savings_label("prompt_cache"), do: "Prompt cache"
  defp savings_label(other), do: other
```

- [ ] **Step 4: Verify it compiles and the page renders**

Run: `mix compile`
Expected: no errors/warnings.

Then run the app and visit `/admin/usage` as an admin (or run any existing LiveView test for the page if present):

Run: `mix test test/rule_maven_web/ 2>&1 | tail -5` (confirm no admin-usage regressions)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/rule_maven_web/live/admin_live/usage.ex
git commit -m "feat: savings panel on the admin usage dashboard"
```

---

## Self-Review

**Spec coverage:**
- Ledger table + `Savings` module → Task 1. ✓
- cache_hit producer (pool hit) + rolling estimator w/ constant fallback → Tasks 3, 4. ✓
- prompt_cache real discount + cached-token capture → Tasks 2, 5. ✓
- cheap_route counterfactual + routing, excluded from headline → Tasks 6, 7. ✓
- Pricing cached rate → Task 2. ✓
- Dashboard view, estimates labeled, cheap_route separated → Task 8. ✓
- Best-effort/non-blocking writes → Task 1 `record/2` (rescue + log-swallow). ✓
- Open items (OpenRouter cached-token key, cached rate fraction, cold-start constants) → flagged in Task 5 note, Task 2 `@cached_rate_fraction`, Task 3 `@fallback_tokens`. ✓

**Note on FAQ:** the spec mentioned "FAQ hits"; in this codebase the answer cache IS the pool, and the community "FAQ" surfaces pooled rows. There is no separate ask-time FAQ cache, so `cache_hit` is wired only at the pool-hit branch (Task 4). No missing task.

**Placeholder scan:** no TBD/TODO; every code step shows concrete code. ✓

**Type consistency:** `record/2`, `estimate_avoided/2` (`%{tokens, usd, model}`), `record_cache_hit/3`, `record_call_savings/3`, `summary/1` (`%{headline_usd, headline_tokens, by_kind}`), `Pricing.cached_savings/2`, `model(:cheap)` — names/shapes consistent across tasks and dashboard. ✓
