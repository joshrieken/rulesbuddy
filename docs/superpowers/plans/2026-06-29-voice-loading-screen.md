# Voice Loading Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user switches to an uncached persona voice, clear the visible answer text and show a SimCity-style loading panel (cycling nonsense phrase + faux progress bar + retro spinner) until the restyle arrives.

**Architecture:** Phrase pools are voice-flavored: globals get a hardcoded `:loading` list, generated game voices get an LLM-returned `loading_phrases` column, and a shared generic pool is always blended in. A single resolver `Voices.loading_phrases/2` returns the merged list. The show LiveView swaps `msg.content` for a loader `<div>` while a restyle is pending; a client-side JS hook animates it. No new server messaging — completion is the existing `{:voice_ready}` PubSub path.

**Tech Stack:** Elixir / Phoenix LiveView, Ecto/Postgres, vanilla JS hooks in `priv/static/assets/js/app.js`, plain CSS.

## Global Constraints

- LLM prompts (system + user) live ONLY in the `RuleMaven.Prompts` registry, never hardcoded elsewhere.
- Generated voice ids are namespaced `g:<slug>`; never collide with globals.
- `loading_phrases` are tone/flavor ONLY — never rules, numbers, or game facts.
- No backfill of existing generated voices; nil/empty `loading_phrases` falls back to the generic pool.
- The resolver must NEVER return an empty list.
- Commit after each task.

---

### Task 1: Generic pool + global voice phrases + resolver

**Files:**
- Modify: `lib/rule_maven/voices.ex` (the `@voices` list ~lines 38-69; add `@generic_loading` module attr and `loading_phrases/2` + a private `def_loading` helper)
- Test: `test/rule_maven/voices_test.exs`

**Interfaces:**
- Produces:
  - `Voices.loading_phrases(voice :: String.t(), game :: %Game{} | id | nil) :: [String.t()]` — voice's own phrases ++ generic pool, de-duplicated, never empty.
  - Each global `@voices` entry (except `neutral`) gains a `:loading` key (`[String.t()]`). `neutral` keeps no loading phrases (it never pends).

- [ ] **Step 1: Write the failing tests**

Add to `test/rule_maven/voices_test.exs` inside a new describe block:

```elixir
describe "loading_phrases/2" do
  test "returns a non-empty list for neutral (generic pool only)" do
    g = game()
    phrases = Voices.loading_phrases("neutral", g)
    assert is_list(phrases) and phrases != []
    assert Enum.all?(phrases, &is_binary/1)
  end

  test "returns a non-empty list for an unknown voice (generic pool only)" do
    g = game()
    assert Voices.loading_phrases("does-not-exist", g) != []
  end

  test "global voice phrases come before the generic pool and include both" do
    g = game()
    phrases = Voices.loading_phrases("pirate", g)
    pirate_own = Voices.get_def("pirate").loading
    assert pirate_own != []
    # the voice's own phrases are present
    assert Enum.all?(pirate_own, &(&1 in phrases))
    # generic pool is blended in (more than just the voice's own)
    assert length(phrases) > length(pirate_own)
  end

  test "de-duplicates phrases" do
    g = game()
    phrases = Voices.loading_phrases("pirate", g)
    assert phrases == Enum.uniq(phrases)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/rule_maven/voices_test.exs -o tmp/voices_test.log 2>&1; cat tmp/voices_test.log`
Expected: FAIL — `Voices.loading_phrases/2` undefined (and `get_def("pirate").loading` key missing).

- [ ] **Step 3: Add a `:loading` list to each global voice**

In `lib/rule_maven/voices.ex`, in the `@voices` list, add a `loading:` key to each non-neutral entry. `neutral` stays unchanged. Example final shape for each:

```elixir
%{
  id: "lawyer",
  label: "Rules Lawyer",
  emoji: "🧑‍⚖️",
  style: "a rules lawyer who treats every ruling like a courtroom win ...",
  loading: [
    "Filing the motion…",
    "Citing precedent…",
    "Objecting on principle…",
    "Reviewing the bylaws…",
    "Stamping the verdict…"
  ]
},
```

Use these lists:

```elixir
# pirate
loading: ["Swabbing the rules…", "Consulting the charts…", "Hoisting the errata…", "Counting the doubloons…", "Sighing at landlubbers…"]
# robot
loading: ["Parsing directive…", "Logging your infraction…", "Recalibrating authority…", "Buffering ruling…", "Asserting compliance…"]
# coach
loading: ["Hyping the play…", "Drawing up the rule…", "Calling the timeout…", "Believing in you…", "Rallying the table…"]
```

`neutral` gets no `:loading` key (resolver tolerates its absence).

- [ ] **Step 4: Add the generic pool attribute**

Near the top of `lib/rule_maven/voices.ex` (after `@game_prefix`), add:

```elixir
# Shared SimCity-style nonsense, blended into every voice's loading screen so the
# panel never looks sparse. Flavor only — never rules or facts.
@generic_loading [
  "Reticulating splines…",
  "Consulting the errata…",
  "Bribing the rules lawyer…",
  "Re-shuffling the meeples…",
  "Aligning the hex grid…",
  "Untangling the turn order…",
  "Waking the rules lawyer…",
  "Calibrating the dice…"
]
```

- [ ] **Step 5: Implement `loading_phrases/2`**

Add public function (e.g. just after `get_def/2` definitions):

```elixir
@doc """
Loading-screen phrases for a voice within a game's scope: the voice's own
phrases (global `:loading` or a generated voice's `loading_phrases`) followed
by the shared generic pool, de-duplicated. Never returns an empty list.
"""
def loading_phrases(voice, game) do
  own =
    case get_def(voice, game) do
      %{loading: l} when is_list(l) -> l
      %{loading_phrases: l} when is_list(l) -> l
      _ -> []
    end

  (own ++ @generic_loading) |> Enum.reject(&(&1 in [nil, ""])) |> Enum.uniq()
end
```

Note: global defs expose `:loading`; generated defs (Task 3) expose `:loading_phrases`. Both clauses are handled.

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/rule_maven/voices_test.exs -o tmp/voices_test.log 2>&1; cat tmp/voices_test.log`
Expected: PASS. Then `rm -f tmp/voices_test.log`.

- [ ] **Step 7: Commit**

```bash
git add lib/rule_maven/voices.ex test/rule_maven/voices_test.exs
git commit -m "feat: voice loading-screen phrase pools + resolver"
```

---

### Task 2: Persist generated `loading_phrases` (migration + schema + resolver wiring)

**Files:**
- Create: `priv/repo/migrations/20260629070000_add_loading_phrases_to_game_voices.exs`
- Modify: `lib/rule_maven/voices/game_voice.ex` (schema fields + changeset cast)
- Modify: `lib/rule_maven/voices.ex` — `game_voice_defs/1` select (~lines 90-100) and `replace_generated/2` attrs map (~line 218)
- Test: `test/rule_maven/voices_test.exs`

**Interfaces:**
- Consumes: `Voices.loading_phrases/2` (Task 1) reads `:loading_phrases` from generated defs.
- Produces:
  - `GameVoice` schema field `loading_phrases :: [String.t()]` (default `[]`).
  - `Voices.game_voice_defs/1` maps now include `loading_phrases: [String.t()]`.
  - `Voices.replace_generated/2` accepts `%{... loading_phrases: [String.t()]}` on each voice (optional; defaults to `[]`).

- [ ] **Step 1: Write the failing test**

Add to `test/rule_maven/voices_test.exs`:

```elixir
describe "loading_phrases/2 for generated voices" do
  test "generated voice's stored phrases precede the generic pool" do
    g = game()

    :ok =
      Voices.replace_generated(g.id, [
        %{
          slug: "herald",
          label: "Woodland Herald",
          emoji: "🦉",
          style: "a courtly herald",
          loading_phrases: ["Sounding the horn…", "Unrolling the scroll…"]
        }
      ])

    phrases = Voices.loading_phrases("g:herald", g)
    assert "Sounding the horn…" in phrases
    assert "Unrolling the scroll…" in phrases
    # generic pool still blended
    assert "Reticulating splines…" in phrases
  end

  test "generated voice without loading_phrases falls back to generic only" do
    g = game()

    :ok =
      Voices.replace_generated(g.id, [
        %{slug: "plain-gen", label: "Plain Gen", emoji: "🙂", style: "a plain narrator"}
      ])

    phrases = Voices.loading_phrases("g:plain-gen", g)
    assert phrases != []
    assert "Reticulating splines…" in phrases
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/rule_maven/voices_test.exs -o tmp/voices_test.log 2>&1; cat tmp/voices_test.log`
Expected: FAIL — `loading_phrases` not cast/stored (or key error in `replace_generated`).

- [ ] **Step 3: Write the migration**

Create `priv/repo/migrations/20260629070000_add_loading_phrases_to_game_voices.exs`:

```elixir
defmodule RuleMaven.Repo.Migrations.AddLoadingPhrasesToGameVoices do
  use Ecto.Migration

  def change do
    alter table(:game_voices) do
      add :loading_phrases, {:array, :text}, default: []
    end
  end
end
```

- [ ] **Step 4: Run the migration**

Run: `mix ecto.migrate 2>&1 | tail -5`
Expected: shows the alter table executing, no error.

- [ ] **Step 5: Add the schema field + changeset cast**

In `lib/rule_maven/voices/game_voice.ex`, add to the `schema` block (after `:style`):

```elixir
field :loading_phrases, {:array, :string}, default: []
```

And add `:loading_phrases` to the `cast/3` list in `changeset/2`:

```elixir
|> cast(attrs, [:game_id, :slug, :label, :emoji, :style, :loading_phrases, :source, :position])
```

(Do NOT add it to `validate_required`.)

- [ ] **Step 6: Expose it in `game_voice_defs/1` and persist it in `replace_generated/2`**

In `lib/rule_maven/voices.ex`, `game_voice_defs/1`, extend the `select` and the mapped def:

```elixir
select: %{
  slug: gv.slug,
  label: gv.label,
  emoji: gv.emoji,
  style: gv.style,
  loading_phrases: gv.loading_phrases
}
```

```elixir
|> Enum.map(fn gv ->
  %{
    id: @game_prefix <> gv.slug,
    label: gv.label,
    emoji: gv.emoji,
    style: gv.style,
    loading_phrases: gv.loading_phrases || []
  }
end)
```

In `replace_generated/2`, add to the `attrs` map:

```elixir
loading_phrases: Map.get(v, :loading_phrases, []),
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `mix test test/rule_maven/voices_test.exs -o tmp/voices_test.log 2>&1; cat tmp/voices_test.log`
Expected: PASS (Task 1 + Task 2 tests). Then `rm -f tmp/voices_test.log`.

- [ ] **Step 8: Commit**

```bash
git add priv/repo/migrations/20260629070000_add_loading_phrases_to_game_voices.exs lib/rule_maven/voices/game_voice.ex lib/rule_maven/voices.ex test/rule_maven/voices_test.exs
git commit -m "feat: persist generated voice loading_phrases"
```

---

### Task 3: LLM prompt + parse `loading_phrases`

**Files:**
- Modify: `lib/rule_maven/prompts.ex` — `@generate_voices` template (~lines 407-442)
- Modify: `lib/rule_maven/llm.ex` — `coerce_voice/1` (~line 1306)
- Test: `test/rule_maven/llm_parse_defects_test.exs` (or `llm_test.exs` if that's where parse_voices coverage lives — check first; create a describe block in whichever already tests `parse_voices`. If neither does, add to `test/rule_maven/llm_test.exs`.)

**Interfaces:**
- Consumes: `Voices.replace_generated/2` reads `:loading_phrases` (Task 2).
- Produces: `parse_voices/1` output maps now include `:loading_phrases :: [String.t()]` (default `[]`, only non-empty trimmed strings, capped at 6 entries).

- [ ] **Step 1: Write the failing test**

`parse_voices/1` is private. Test it through the public boundary if one exists, else add a thin test using the module's existing test access pattern. First check how existing tests exercise voice parsing:

Run: `grep -rn "parse_voices\|coerce_voice\|generate_voices" test/ lib/rule_maven/llm.ex | head`

If a public function or existing test seam exists, use it. Otherwise add this test to `test/rule_maven/llm_test.exs`, calling the private fn via `:erlang.apply` is NOT allowed — instead, expose parsing through the smallest existing public surface. If `parse_voices` has no public seam, add a `@doc false` public wrapper `def __parse_voices__(text), do: parse_voices(text)` in `llm.ex` guarded with a comment "test seam", and test that.

Test body:

```elixir
describe "voice parsing includes loading_phrases" do
  test "parses loading_phrases when present" do
    json = ~s([{"slug":"herald","label":"Herald","emoji":"🦉","style":"a courtly herald","loading_phrases":["Sounding the horn…","Unrolling the scroll…"]}])
    [v] = RuleMaven.LLM.__parse_voices__(json)
    assert v.loading_phrases == ["Sounding the horn…", "Unrolling the scroll…"]
  end

  test "defaults loading_phrases to [] when missing" do
    json = ~s([{"slug":"herald","label":"Herald","emoji":"🦉","style":"a courtly herald"}])
    [v] = RuleMaven.LLM.__parse_voices__(json)
    assert v.loading_phrases == []
  end

  test "drops non-string and blank loading_phrases entries" do
    json = ~s([{"slug":"h","label":"H","emoji":"🦉","style":"x","loading_phrases":["ok ", 3, "", "  ", "two"]}])
    [v] = RuleMaven.LLM.__parse_voices__(json)
    assert v.loading_phrases == ["ok", "two"]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/rule_maven/llm_test.exs -o tmp/llm_test.log 2>&1; cat tmp/llm_test.log`
Expected: FAIL — `__parse_voices__/1` undefined and/or `:loading_phrases` key missing.

- [ ] **Step 3: Add the test seam + parse loading_phrases**

In `lib/rule_maven/llm.ex`, add a `@doc false` wrapper near `parse_voices/1`:

```elixir
@doc false
# Test seam for parse_voices/1.
def __parse_voices__(text), do: parse_voices(text)
```

Update `coerce_voice/1` to extract `loading_phrases`:

```elixir
defp coerce_voice(%{"label" => label, "emoji" => emoji, "style" => style} = m)
     when is_binary(label) and is_binary(emoji) and is_binary(style) do
  label = String.trim(label)
  style = String.trim(style)
  slug = m |> Map.get("slug", label) |> to_string() |> slugify()
  loading = m |> Map.get("loading_phrases", []) |> coerce_phrases()

  if label != "" and style != "" and slug != "" do
    %{slug: slug, label: label, emoji: String.trim(emoji), style: style, loading_phrases: loading}
  end
end

defp coerce_voice(_), do: nil

# Keep only non-blank string phrases, trimmed, capped at 6.
defp coerce_phrases(list) when is_list(list) do
  list
  |> Enum.filter(&is_binary/1)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.take(6)
end

defp coerce_phrases(_), do: []
```

- [ ] **Step 4: Update the generation prompt**

In `lib/rule_maven/prompts.ex`, `@generate_voices`, extend the JSON shape block and rules. Change the object shape to:

```
  [
    {
      "slug": "kebab-case-stable-id",
      "label": "Short Display Name",
      "emoji": "🙂",
      "style": "a one-sentence description of how this persona talks, in the same form as 'a swashbuckling pirate who uses nautical slang.'",
      "loading_phrases": ["Hoisting the sails…", "Counting the doubloons…", "Sighing at landlubbers…"]
    }
  ]
```

Add to the `Rules:` list:

```
  - "loading_phrases" is an array of 4-6 very short (≤ 5 words) in-character
    "loading screen" status lines for THIS persona — playful nonsense in the
    spirit of old SimCity loaders ("Reticulating splines…"), each ending with an
    ellipsis. They are flavor ONLY: never a rule, number, or game fact.
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/rule_maven/llm_test.exs -o tmp/llm_test.log 2>&1; cat tmp/llm_test.log`
Expected: PASS. Then `rm -f tmp/llm_test.log`.

- [ ] **Step 6: Commit**

```bash
git add lib/rule_maven/prompts.ex lib/rule_maven/llm.ex test/rule_maven/llm_test.exs
git commit -m "feat: LLM generates per-voice loading_phrases"
```

---

### Task 4: LiveView swaps stale text for the loader panel

**Files:**
- Modify: `lib/rule_maven_web/live/game_live/show.ex` — the pending block at ~lines 2032-2039
- Modify: `lib/rule_maven/voices.ex` — confirm `loading_phrases/2` is the public entry (already from Task 1)

**Interfaces:**
- Consumes: `Voices.loading_phrases/2` (Task 1/2), `@game`, `v_sel`, `v_pending`, `v_content`, `msg[:id]`, `msg.content`.
- Produces: a `.voice-loader` div with `phx-hook="VoiceLoader"`, `phx-update="ignore"`, `data-phrases` (JSON array) consumed by the JS hook in Task 5.

- [ ] **Step 1: Replace the pending block**

In `lib/rule_maven_web/live/game_live/show.ex`, change the `<div class="answer-in">` block (currently lines ~2032-2039) from:

```heex
<div class="answer-in">
  <%= if v_pending && is_nil(v_content) do %>
    <div style="font-size:0.68rem;opacity:0.7;font-style:italic;margin-bottom:0.3rem;color:var(--text-muted)">
      🎭 putting it in character…
    </div>
  <% end %>
  {render_markdown(v_content || msg.content)}
</div>
```

to:

```heex
<div class="answer-in">
  <%= if v_pending && is_nil(v_content) do %>
    <div
      class="voice-loader"
      id={"voice-loader-#{msg[:id]}"}
      phx-hook="VoiceLoader"
      phx-update="ignore"
      data-phrases={Jason.encode!(RuleMaven.Voices.loading_phrases(v_sel, @game))}
    >
      <div class="voice-loader__row">
        <span class="voice-loader__spinner" aria-hidden="true"></span>
        <span class="voice-loader__phrase">Reticulating splines…</span>
      </div>
      <div class="voice-loader__bar"><div class="voice-loader__fill"></div></div>
    </div>
  <% else %>
    {render_markdown(v_content || msg.content)}
  <% end %>
</div>
```

Note: `{render_markdown(...)}` now lives in the `<% else %>` branch — the stale text is no longer rendered while pending. That is the "clear existing text" requirement.

- [ ] **Step 2: Verify it compiles**

Run: `mix compile 2>&1 | tail -5`
Expected: compiles, no warnings about `RuleMaven.Voices.loading_phrases/2`.

- [ ] **Step 3: Verify nothing else references the old caption**

Run: `grep -rn "putting it in character" lib/`
Expected: no matches (the only occurrence was the one just replaced).

- [ ] **Step 4: Commit**

```bash
git add lib/rule_maven_web/live/game_live/show.ex
git commit -m "feat: show voice loader panel, clearing stale text while restyling"
```

---

### Task 5: JS hook + CSS animation

**Files:**
- Modify: `lib/rule_maven_web/live/game_live/show.ex` is NOT where CSS lives — locate the chat CSS. Run the grep in Step 0 to find the stylesheet that holds `.answer-in` / `.conf-pill`.
- Modify: `priv/static/assets/js/app.js` — add `Hooks.VoiceLoader` (after `Hooks.VoiceDefault`, ~line 591) and ensure it's in the `Hooks` object (it already auto-registers since hooks attach as `Hooks.Name`).
- Modify: the chat stylesheet found in Step 0 — add `.voice-loader*` rules.

**Interfaces:**
- Consumes: `data-phrases` JSON array from Task 4's `.voice-loader` div.

- [ ] **Step 0: Find the stylesheet and confirm hooks wiring**

Run: `grep -rln "\.conf-pill\|\.answer-in" priv/static assets 2>/dev/null; grep -n "Hooks.VoiceDefault\|hooks: Hooks" priv/static/assets/js/app.js`
Expected: prints the CSS file path holding `.conf-pill`/`.answer-in`, and confirms `hooks: Hooks` registration (line ~781). Use that CSS file path in the steps below (referred to as `CHAT_CSS`).

If `.conf-pill` lives in a `.heex`/`<style>` block rather than a `.css` file, add the new rules in that same `<style>` block instead.

- [ ] **Step 1: Add the `VoiceLoader` hook**

In `priv/static/assets/js/app.js`, after the `Hooks.VoiceDefault = { ... }` block, add:

```javascript
Hooks.VoiceLoader = {
  mounted() {
    let phrases;
    try {
      phrases = JSON.parse(this.el.dataset.phrases || "[]");
    } catch (_e) {
      phrases = [];
    }
    if (!phrases.length) phrases = ["Reticulating splines…"];

    const phraseEl = this.el.querySelector(".voice-loader__phrase");
    const fillEl = this.el.querySelector(".voice-loader__fill");
    let last = -1;
    let pct = 8;

    const pickPhrase = () => {
      let i = Math.floor(Math.random() * phrases.length);
      if (phrases.length > 1 && i === last) i = (i + 1) % phrases.length;
      last = i;
      if (phraseEl) phraseEl.textContent = phrases[i];
    };

    const stepBar = () => {
      // Eased random crawl toward ~90%, with occasional retro hiccup resets.
      if (Math.random() < 0.08 && pct > 30) pct -= 10;
      pct += Math.random() * (pct < 60 ? 9 : 3);
      if (pct > 92) pct = 92;
      if (fillEl) fillEl.style.width = pct.toFixed(1) + "%";
    };

    pickPhrase();
    stepBar();
    this._phraseTimer = setInterval(pickPhrase, 700);
    this._barTimer = setInterval(stepBar, 250);
  },
  destroyed() {
    clearInterval(this._phraseTimer);
    clearInterval(this._barTimer);
  }
};
```

- [ ] **Step 2: Add the CSS**

Append to `CHAT_CSS` (the file/block found in Step 0):

```css
.voice-loader {
  margin: 0.15rem 0 0.35rem;
}
.voice-loader__row {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.72rem;
  font-style: italic;
  color: var(--text-muted);
}
.voice-loader__spinner {
  display: inline-block;
  width: 1ch;
  text-align: center;
}
.voice-loader__spinner::before {
  content: "⠋";
  animation: voice-loader-spin 0.8s steps(1) infinite;
}
@keyframes voice-loader-spin {
  0%   { content: "⠋"; }
  12%  { content: "⠙"; }
  25%  { content: "⠹"; }
  37%  { content: "⠸"; }
  50%  { content: "⠼"; }
  62%  { content: "⠴"; }
  75%  { content: "⠦"; }
  87%  { content: "⠧"; }
  100% { content: "⠇"; }
}
.voice-loader__bar {
  margin-top: 0.3rem;
  height: 6px;
  border-radius: 3px;
  background: var(--bg-subtle);
  border: 1px solid var(--border);
  overflow: hidden;
}
.voice-loader__fill {
  height: 100%;
  width: 8%;
  background: var(--accent);
  transition: width 0.25s ease-out;
}
```

- [ ] **Step 3: Verify hook registers and compiles**

Run: `mix compile 2>&1 | tail -3`
Expected: compiles clean. (JS is static — no build step.)

- [ ] **Step 4: In-browser verification (puppeteer + auto-login token)**

Per the project's in-browser verify convention: start the server, log in via auto-login token, open a game with at least one answered question, switch to an uncached persona voice, and confirm:
- The previous answer text disappears immediately.
- The loader shows a spinning glyph, a cycling phrase, and a growing bar.
- When the restyle finishes, the loader is replaced by the restyled answer.

Capture a screenshot of the loader mid-animation to `tmp/voice-loader.png` for the review.

- [ ] **Step 5: Commit**

```bash
git add priv/static/assets/js/app.js <CHAT_CSS path>
git commit -m "feat: animate voice loader (retro spinner + crawling bar)"
```

---

## Self-Review

**Spec coverage:**
- Clear stale text while pending → Task 4 (else-branch move). ✓
- Bar + retro spinner glyph + cycling phrase → Task 5. ✓
- Global voice-flavored phrases → Task 1. ✓
- Generated voice phrases via LLM JSON + column → Tasks 2 & 3. ✓
- Generic fallback pool, never empty → Task 1 (`@generic_loading`, resolver). ✓
- No backfill; nil falls back to generic → Task 2 (nullable column, resolver tolerates `[]`). ✓
- Prompts in registry → Task 3 edits `Prompts`, not inline. ✓
- Client-side only, no new server messaging → Task 5 hook; completion via existing `{:voice_ready}`. ✓
- Tests for resolver, parse, changeset round-trip, in-browser → Tasks 1/2/3/5. ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete. CSS/JS file path is resolved at execution via a concrete grep in Task 5 Step 0 (codebase-dependent, not a placeholder).

**Type consistency:** `loading_phrases/2` used identically across tasks. Global defs expose `:loading`; generated defs expose `:loading_phrases`; resolver handles both clauses (Task 1 Step 5). `__parse_voices__/1` seam defined in Task 3 Step 3, used in Task 3 Step 1. `data-phrases` JSON produced in Task 4, consumed in Task 5. Consistent.
