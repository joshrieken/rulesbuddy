# Data Flows

## Ask a Question

```
GameLive.Show (form submit)
  → Games.log_question/1 (insert QuestionLog)
  → Games.retrieve_chunks/3 (vector search on embeddings)
  → LLM.ask/4 (build prompt with chunks + game sources)
    → Faq.check_faq_cache/2 (embedding similarity check first)
      → HIT: return cached answer (no LLM call)
      → MISS: LLM.chat/3 → parse response → return cited answer
  → Games.log_question_update/2 (save answer, citation, provider)
  → LiveView: prepend to conversation, scroll bottom
  → Oban.insert(DirectPromotionWorker) (auto-promote exact-match to FAQ)
```

Key files:
- `lib/rule_maven_web/live/game_live/show.ex` — LiveView handler: `handle_event("ask", ...)`
- `lib/rule_maven/games.ex` — `log_question/1`, `retrieve_chunks/3`, `log_question_update/2`
- `lib/rule_maven/llm.ex` — `ask/4` (FAQ check + retrieval + LLM call)
- `lib/rule_maven/faq.ex` — `check_faq_cache/2` (private, embedding similarity)
- `lib/rule_maven/workers/direct_promotion_worker.ex` — auto-promotion

## Save Rulebook

```
GameLive.Form (save_game/4)
  → Games.create_game/1 OR Games.update_game/2
  → Games.create_document/1 (attrs with full_text)
    → insert Document
    → chunk_document/1 (split text, insert Chunks)
    → Oban.insert(EmbedChunksWorker) (embed chunks in background)
    → Oban.insert(CheatSheetWorker) (generate cheatsheet, skipped in test)
  → push_navigate to edit page
```

When user navigates to game show page later:
```
GameLive.Show handle_params
  → if sources exist, send self {:refresh_suggestions, game, sources, already_asked}
  → handle_info calls LLM.suggest_questions/3
  → assigns @suggestions, renders suggestion buttons
```

Key files:
- `lib/rule_maven_web/live/game_live/form.ex` — `save_game/4` (new + existing games)
- `lib/rule_maven/games.ex` — `create_game/1`, `update_game/2`, `create_document/1`, `chunk_document/1`
- `lib/rule_maven/workers/embed_chunks_worker.ex` — async embedding
- `lib/rule_maven/workers/cheat_sheet_worker.ex` — async cheatsheet generation
- `lib/rule_maven_web/live/game_live/show.ex` — `handle_params` triggers suggestions

## FAQ Cluster (periodic)

```
FaqClusterJob (Oban cron)
  → FaqClusterWorker.perform/1
    → group questions by embedding similarity
    → create FaqCandidate (canonical question + answer)
    → admin reviews in AdminLive
```

Key files:
- `lib/rule_maven/workers/faq_cluster_job.ex` — Oban job struct (cron config)
- `lib/rule_maven/workers/faq_cluster_worker.ex` — clustering logic
- `lib/rule_maven/faq.ex` — `upsert_candidate/1`, `approve_candidate/2`
- `lib/rule_maven_web/live/admin_live.ex` — admin review UI

## Auto-Promotion (after question answered)

```
DirectPromotionWorker.perform/1
  → check if same question+answer pair already exists as FAQ
  → if exact match or embedding similarity > threshold
    → auto-create FaqCandidate for admin approval
```

Key files:
- `lib/rule_maven/workers/direct_promotion_worker.ex` — promotion logic
- `lib/rule_maven/faq.ex` — `upsert_candidate/1`
