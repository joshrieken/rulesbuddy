# LLM Savings Ledger — Design

**Date:** 2026-06-29
**Status:** Approved (pending spec review)

## Goal

Cut LLM token cost across the app and record what we save in a durable ledger,
viewable in the admin dashboard. The "rtk analog": rather than compressing tool
output, we reduce tokens on outgoing LLM requests and attribute the savings.

Three savings sources feed one ledger and one view.

## Background — what already exists

- `RuleMaven.LLM.Log` (`llm_logs`): per-real-call `prompt_tokens`,
  `completion_tokens`, `total_tokens`, `duration_ms`, `provider`, `model`,
  `operation`, `game_id`, `user_id`.
- `RuleMaven.LLM.Pricing.cost/3`: model → USD from token counts (substring match
  on model id, fallback rate for unknown models).
- Admin cost dashboard + per-user daily cost cap (reads `LLM.usage/1` style
  roll-ups).
- `RuleMaven.LLMProxy` (optional Headroom routing via `LLM_PROXY_URL`).
- Answer **pool cache** (`find_similar_question_in_pool/3`) and **FAQ hits** —
  both serve a cached answer and avoid a full LLM ask.
- Question **normalize** step (canonicalizes questions before the pool lookup),
  which raises the pool hit rate.

Key gap: a cache/pool/FAQ **hit creates no `LLM.Log` row** (no call = no log), so
avoided-call savings currently have nowhere to land.

## Non-goals (YAGNI)

- Pre-send prompt compression (stripping/dedup of outgoing prompts). Explicitly
  out — too easy to over-trim and hurt answer quality.
- Rerouting **answers** to cheaper models. Cheap routing is limited to the
  existing cheap-op set.
- Any new infrastructure beyond the one ledger table.

## Architecture

```
ask → normalize → pool/FAQ lookup
  ├─ hit  → serve cached answer + Savings.record(:cache_hit, estimate)
  └─ miss → call_llm → response
              ├─ LLM.Log (real call, unchanged)
              └─ if cached_tokens > 0 → Savings.record(:prompt_cache, real_discount)

cheap ops (normalize, suggest_questions, did_you_know, categories, setup)
  → run on cheap model → Savings.record(:cheap_route, premium − cheap)  [secondary]
```

### 1. Ledger — `llm_savings` table + `RuleMaven.LLM.Savings`

Migration adds `llm_savings`:

| column            | type            | notes                                            |
|-------------------|-----------------|--------------------------------------------------|
| id                | bigserial       |                                                  |
| kind              | string          | `"cache_hit"` \| `"prompt_cache"` \| `"cheap_route"` |
| operation         | string          | e.g. `"ask"`, `"normalize"`, `"suggest_questions"` |
| estimated_tokens  | integer         | tokens saved/avoided (estimate or real)          |
| estimated_usd     | float           | USD saved (estimate or real)                     |
| model             | string          | model that did / would have run                  |
| game_id           | bigint, null    | FK, nullable                                     |
| user_id           | bigint, null    | FK, nullable                                     |
| inserted_at       | utc_datetime    | (no `updated_at`; rows are append-only)          |

Indexes: `(inserted_at)`, `(kind, inserted_at)` for the dashboard windows.

`RuleMaven.LLM.Savings` module:

- `record(kind, attrs)` — single insert API. Best-effort: a ledger write must
  never break or block the request path (wrap so failures are logged, swallowed).
- `estimate_avoided(operation, game_id)` — rolling-history estimator (see §2a).
- Query fns mirroring `LLM.usage/1` shape:
  - `totals(opts)` — sum tokens + USD over a date window, optionally by kind.
  - `by_kind(opts)`, `by_day(opts)` — for dashboard charts/breakdowns.
  - Headline total **excludes** `cheap_route` (see §2c).

### 2. Three producers

#### (a) cache_hit — avoided whole calls

In `ask/5`, the pool-hit branch and the FAQ-hit branch each call
`Savings.record(:cache_hit, ...)`. Amount comes from the **rolling-history
estimator**:

`estimate_avoided(operation, game_id)`:
1. Query the last **N = 50** successful `LLM.Log` rows for the same `operation`
   (prefer same `game_id`; if fewer than a small minimum for that game, widen to
   all games for that operation).
2. Average their `prompt_tokens` and `completion_tokens`.
3. `estimated_usd = Pricing.cost(default_model, avg_prompt, avg_completion)`;
   `estimated_tokens = avg_prompt + avg_completion`.
4. **Cold-start fallback:** if there is no usable history, use a per-operation
   constant (configurable; conservative default, e.g. `ask ≈ 4000 prompt + 300
   completion`). The constant is *only* a fallback — once real history exists it
   takes over.

This is explicitly an **estimate** (the call never ran), but seeded from real
recent usage so it tracks reality as rulebooks/prompts grow.

#### (b) prompt_cache — real provider discount

The only **real** (non-counterfactual) saving: the provider literally bills
cached input tokens at a lower rate.

- Extend `extract_usage/1` to also read cached prompt tokens from the provider
  usage payload. **The exact OpenRouter/Gemini usage key(s)** (e.g.
  `prompt_tokens_details.cached_tokens`) and whether caching needs an explicit
  `cache_control` breakpoint on the static system prefix vs. relying on Gemini
  implicit caching **must be confirmed against live OpenRouter docs/responses at
  implementation time — not assumed here.**
- The real call still logs to `LLM.Log` unchanged. *Additionally*, when
  `cached_tokens > 0`, record `prompt_cache` with
  `estimated_usd = cached_tokens × (full_input_rate − cached_input_rate)` for
  that model, `estimated_tokens = cached_tokens`.
- Cache target = the large static answer system prefix (the security/instructions
  block sent on every ask). If an explicit breakpoint is required, place it at
  the end of that static prefix so the rulebook/question tail stays uncached.

#### (c) cheap_route — counterfactual, SECONDARY ONLY

Extend the existing `model(:cleanup)` idea into a small routing map:
`{normalize, suggest_questions, did_you_know, categories, setup}` → cheap model.
On those calls, record `cheap_route` with
`estimated_usd = Pricing.cost(premium_model, p, c) − Pricing.cost(cheap_model, p, c)`
on the call's **actual** token counts.

This is a pure counterfactual ("saved vs running it on the answer model") — you
were never going to run these on the premium model. Therefore:

- It is **never summed into the headline savings total.**
- The dashboard shows it as a **faded/secondary stat**, clearly labeled
  "estimated vs running on the answer model."

### 3. Pricing

`Pricing.cost/3` stays. Add an optional **cached-input rate** per model (used by
2b); unknown models fall back to a fraction of the input rate (fraction
confirmed at spec/impl time). The two-model diff for 2c uses the existing
`cost/3` twice — no new pricing primitive needed.

### 4. View — admin dashboard Savings panel

Extend the existing cost dashboard (reuse its date-window control):

- **Headline:** total $ saved in window = `cache_hit` + `prompt_cache` only.
- **Breakdown** by kind: cache hits (estimated), prompt cache (real),
  and — separated/faded — cheap routing (counterfactual).
- Saved tokens, and a **cache hit rate** stat (hits ÷ (hits + real asks)).
- All estimate-based figures labeled "estimated"; kept **visually separate** from
  the real-cost numbers so a cost reader is never misled.

## Honesty guardrails (summary)

| kind         | nature          | in headline? | label              |
|--------------|-----------------|--------------|--------------------|
| prompt_cache | real discount   | yes          | real               |
| cache_hit    | real avoidance, estimated amount | yes | "estimated" |
| cheap_route  | counterfactual  | **no**       | secondary/faded    |

## Error handling

- Ledger writes are best-effort and out of the request's critical path: wrap
  `Savings.record/2` so a failure is logged and swallowed, never surfacing to the
  user or blocking an answer. Mirrors the "background work must be durable /
  non-blocking" principle for the interactive path.
- Estimator with no history must not raise — it returns the constant fallback.
- `extract_usage` must tolerate a missing cached-tokens field (older/other
  providers) and simply record no `prompt_cache` row.

## Testing

- `Savings.record/2` + roll-up queries (`totals`, `by_kind`, `by_day`), modeled
  on `llm_cost_test.exs`.
- `estimate_avoided/2`: with history (averages real logs), with sparse same-game
  history (widens to all games), with **no** history (constant fallback).
- `extract_usage/1`: parses cached tokens when present; no `prompt_cache` row
  when absent.
- Pricing: cached-input rate math; premium−cheap diff for cheap_route.
- Producer wiring: a pool hit writes one `cache_hit` row; a cheap-routed op
  writes one `cheap_route` row; headline total excludes `cheap_route`.

## Open items to pin at implementation time

1. Exact OpenRouter/Gemini usage payload key for cached prompt tokens, and
   whether explicit `cache_control` is needed or Gemini implicit caching suffices.
2. Cached-input rate (fraction of input rate) per model in `Pricing`.
3. Per-operation cold-start constants for the estimator.
