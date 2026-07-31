# Arteria — Viva Preparation & Backend Deep-Dive

> A complete, code-accurate guide to the Arteria backend (`QwenArteria/`, excluding `DeepEval/`).
> Read Part 1–6 to *understand* the system, Part 7 to *defend* it, Part 8 for rapid-fire Q&A.

---

## PART 1 — The 60-Second Elevator Pitch (memorise this)

> "Arteria is a voice-first, conversational blood-pressure companion. Instead of tapping numbers into a form, a hypertensive patient simply *talks* to the app — "my BP was 140 over 90 this morning, I took my amlodipine but skipped my walk" — and the system records the reading, classifies it against the 2025 AHA/ACC guidelines, logs the medication and lifestyle context, and replies in a warm, spoken voice like a careful doctor.
>
> The intelligence is a **hybrid LLM architecture**. A large cloud reasoning model (GPT-5-family) handles *language understanding* — pulling structured meaning out of messy, vague, multilingual speech — while a **locally fine-tuned Qwen3-8B model** ("Arteria") handles the *medical analysis*. A deterministic Python layer owns anything safety-critical (the actual BP classification and the literal numbers), so the LLM can never hallucinate a clinical category or misquote a reading.
>
> Around that core I built a multi-agent LangGraph fallback, a Model-Context-Protocol tool layer for database actions, multi-turn memory, and a novel **voice-stress biomarker** feature that estimates the user's stress from acoustic features of their speech and correlates it with their blood pressure over time."

**The thesis contribution in one line:** *using LLMs to make blood-pressure self-monitoring conversational, proactive, and emotionally aware — while keeping every clinical decision deterministic and auditable.*

---

## PART 2 — System Architecture (the big picture)

### 2.1 The components

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| **API server** | FastAPI (`api_server.py`) | HTTP entry point, request routing, TTS, streaming |
| **Understanding model** | GPT-5-family via OpenAI API (`gpt-5.4-mini` default) | Intent detection, entity extraction, response polishing |
| **Medical model** | Fine-tuned Qwen3-8B ("arteria") served by **Ollama** | BP analysis, recommendations, risk/trend reasoning |
| **Hybrid orchestrator** | `hybrid_orchestrator.py` | Routes between GPT and Qwen, multi-turn state machine |
| **Multi-agent fallback** | LangGraph `StateGraph` (`langgraph_agents.py`) | Local-only intelligence when cloud is unavailable |
| **Intent classifier** | `semantic_intent_classifier.py` | Multi-strategy weighted-vote intent classification |
| **Tool layer** | `mcp_server.py` (Model Context Protocol) | Database actions (record BP, add med, set reminder…) |
| **Data layer** | Firebase Firestore (`firebase_context.py`) | User profile, BP readings, medications, reminders |
| **Memory** | `conversation_memory.py` + `enhanced_conversation_memory.py` | Turn history + semantic/importance-scored memory |
| **Voice** | OpenAI Whisper (STT) + OpenAI/ElevenLabs (TTS) + `voice_sentiment_service.py` | Transcription, speech synthesis, stress biomarkers |
| **Supporting agents** | proactive intelligence, medication optimizer, user preferences | Proactive insights, drug interactions, personalisation |
| **Observability** | `telemetry.py` (OpenTelemetry) | Distributed tracing spans (opt-in) |

### 2.2 The defining idea: a **three-tier graceful-degradation** pipeline

The main `/chat` endpoint tries three processing tiers in order, each a complete fallback for the one above:

```
USER MESSAGE
   │
   ▼
┌──────────────────────────────────────────────┐
│ TIER 1 — HYBRID  (best quality, needs internet)│
│   GPT understands → Qwen analyses → GPT polishes│
└──────────────────────────────────────────────┘
   │ (on exception)
   ▼
┌──────────────────────────────────────────────┐
│ TIER 2 — LANGGRAPH  (good, fully local)        │
│   semantic router → specialised agent node     │
└──────────────────────────────────────────────┘
   │ (if disabled/unavailable)
   ▼
┌──────────────────────────────────────────────┐
│ TIER 3 — DIRECT OLLAMA  (basic, always works)  │
│   context + history → single Qwen call         │
└──────────────────────────────────────────────┘
```

> **Why this matters for the viva:** it shows *engineering maturity*. The system never goes dark. If the OpenAI key is missing or the network drops, it silently falls to a fully-local model. If LangGraph itself fails to import, it falls to a raw Ollama call. This is the answer to "what happens when the cloud is down?"

### 2.3 The hybrid flow in detail (Tier 1)

```
                    ┌─────────────────────────────────────────────┐
  "my bp was 140    │  STEP 1: GPT.detect_intent()                │
   over 90 today" ──┼─►  Returns structured JSON:                 │
                    │    { intent: bp_analysis, confidence: 0.9,  │
                    │      entities: {bp_reading:{140,90}},        │
                    │      flags: {}, clarification: null }        │
                    └─────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────────────┐
                    │  STEP 2: route to handler → _handle_bp_*    │
                    │   • record reading via MCP tool             │
                    │   • classify_bp() deterministically (Python)│
                    │   • ask Qwen /hybrid/analyze for analysis   │
                    └─────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────────────┐
                    │  STEP 3: GPT.generate_response()            │
                    │   Turns the structured analysis into a warm,│
                    │   spoken reply. BP numbers are MASKED as    │
                    │   placeholder tokens so GPT can't alter them│
                    └─────────────────────────────────────────────┘
                                      │
                                      ▼
                          natural language reply → TTS
```

**Division of labour to quote:** *"GPT owns every word; Python owns every number and every clinical category."*

---

## PART 3 — File-by-File Deep Dive

### 3.1 `api_server.py` — the FastAPI gateway (2026 lines)

**What it is:** the HTTP front door. Defines all endpoints, the Pydantic request/response models, and the inference-backend abstraction.

**Key endpoints:**
- `POST /chat` — main conversational endpoint (three-tier).
- `POST /chat/stream` — Server-Sent-Events streaming variant.
- `POST /analyze` — structured BP-reading analysis (systolic/diastolic in, classification + advice out).
- `POST /hybrid/analyze` — **internal** endpoint the orchestrator calls to reach Qwen (not called by the app directly).
- `POST /hybrid/audio`, `POST /transcribe`, `POST /chat/voice-aware` — audio pipelines.
- `POST /medication/interactions` — drug/food interaction check.
- `GET /voice/stress-correlation/{user_id}` — stress-vs-BP analytics.
- `POST /speak` — OpenAI TTS, returns MP3.
- `POST /v1/chat/completions` — OpenAI-compatible shim (lets external tools like ElevenLabs ConvAI talk to the local model).
- `GET /health`, `POST /session/clear`, `GET /mcp/*`.

**The Strategy Pattern for backends** (`BaseBackend`): two concrete implementations.
- `OllamaBackend` — talks to a local Ollama server over HTTP (`/api/generate`); supports streaming (NDJSON) and on-the-fly stripping of Qwen `<think>` tags. **This is the default.**
- `TransformersBackend` — loads the merged HuggingFace model directly onto MPS (Apple Silicon GPU) / CUDA / CPU for direct inference without Ollama.

**Why the Strategy Pattern?** "So I can swap the inference engine — local Ollama, direct GPU, or a remote endpoint — without touching any business logic. Selected with a CLI flag `--backend`."

**The dual-layer classification guardrail** (lines ~122–158): the `SYSTEM_PROMPT` embeds the AHA/ACC rules *and* the backend runs its own deterministic `classify_bp()`. The comment says it plainly: *"LLMs can hallucinate medical classifications… the backend also performs its own deterministic classification for the API response."* The LLM's job is personalised prose; Python's job is the actual category.

The three handler tiers inside `/chat` each: build Firebase context → fetch history → run their model → persist to both memory systems → return a `ChatResponse`. Tier 3 additionally folds in **proactive insights** from two independent sources (the proactive agent + enhanced-memory pattern analysis).

### 3.2 `hybrid_orchestrator.py` — the brain (3358 lines, the most important file)

This is where the GPT↔Qwen choreography lives. Study this hardest.

**`GPTService`** — wraps OpenAI Chat Completions. Three jobs:
1. `detect_intent()` — sends a large few-shot system prompt and returns a structured `IntentResult` (intent enum, confidence, entities, flags, sub-intent, optional clarification). Uses **JSON mode** (`response_format={"type":"json_object"}`) so the reply is *guaranteed* parseable JSON — this killed a whole class of "model wrote prose, parser silently fell back to GENERAL" bugs.
2. `generate_response()` — turns structured analysis into warm spoken language (the "polish" step).
3. Specialised single-call helpers: `generate_interaction_response()` (drug-interaction safety) and `generate_medication_info_response()` (drug education) — these skip the Qwen hop entirely for latency, because GPT is a stronger drug-interaction checker than the 8B model and these are one-shot Q&A.

> **Note on the model:** the code defaults to `OPENAI_MODEL = "gpt-5.4-mini-2026-03-17"`, a GPT-5-family reasoning model, configurable by env var. It sends `max_completion_tokens` + `reasoning_effort` (not the legacy `max_tokens`/`temperature`) — temperature is intentionally *not* sent because reasoning models reject non-default sampling. (Some older docstrings still say "GPT-4o-mini"; the model is env-swappable and was upgraded — say that if asked.)

**The BP-number-faithfulness trick** (`_mask_verbatim_bp` / `_restore_bp_placeholders`) — *this is a signature detail examiners love.*
- Problem: the polish LLM is great at phrasing but unreliable at copying digits — it once spoke a stored `124/76` as "124 over 74".
- Solution: before the analysis reaches GPT, replace definite single-reading systolic/diastolic values with opaque tokens `<<SYSTOLIC>>`/`<<DIASTOLIC>>`. GPT writes the sentence around the tokens; Python substitutes the real numbers back afterwards. If GPT ignores the tokens, there's a **retry** that bluntly re-instructs it, and a regex scrubber strips any leftover token debris before TTS.
- Trend/history analyses are deliberately *not* masked (they summarise many readings, not quote one).

**The multi-turn slot-filling state machine** — `PendingAction` dataclass.
- When a user says "add telmisartan" without a dose, the orchestrator stores a `PendingAction(action_type="add_medication", data={...}, missing=["dosage","time"])` keyed by `user_id`, expiring after **10 minutes**.
- The next turn, "40mg at 8am" fills both slots and executes. A fast multilingual **regex** path tries first (free, instant); whatever regex can't parse falls to an LLM slot-extractor (`extract_medication_slots`) that understands vague phrasing in any language and reports `is_answering` — if the user changed the subject, the pending action is abandoned and the normal pipeline answers them.
- Concurrency: every user has an `asyncio.Lock` so two overlapping requests can't corrupt the slot state (read-modify-write safety).

**Medication-name correction** (`correct_medication_name`, `correct_medication_terms_in_text`): Whisper mangles foreign drug names into ordinary words ("telle mise au temps" → "telmisartan"). A hand-built `MEDICATION_CORRECTIONS` lookup catches known mishearings, then a `SequenceMatcher` fuzzy match (thresholds 0.70–0.80 depending on token count) repairs the rest *before* intent classification runs.

**Conversation-aware nudge** (`bot_last_asked_about_meds`): if the assistant's previous turn asked "are you taking any medications?" and the user replies "yes, telmisartan", the router *forces* the intent to `medication_query/add` — otherwise the system would look up an empty DB and re-ask the same question (a real bug this fixed).

**Intent handlers** (the routing table): emergency, bp_analysis, latest_reading, medication, history, lifestyle, reminder, multi_data, general — each an `async` method. The medication handler alone dispatches seven sub-intents: add, explain, switch, update, adherence, info, interaction.
- `adherence` ("did I take my pill today?") reads the **real Firestore state** (`takenToday` + `lastTakenAt`), and crucially verifies `lastTakenAt` actually falls on *today's* local date rather than trusting a possibly-stale `takenToday` flag.
- `latest_reading` enriches the bare number with a 14-day baseline, active medications, and recent notes, then flags abnormality so the polish prompt adopts a **clinical "doctor mode"** instead of cheerful default tone.

**Streaming** (`process_user_input_stream`): yields `intent` → `token`* → `complete` events; emergencies/clarifications are delivered as a single chunk, normal responses streamed in 24-char slices.

### 3.3 `langgraph_agents.py` — the local multi-agent system (3817 lines)

**What it is:** Tier 2. A LangGraph `StateGraph` that runs entirely on the local Qwen model — the "offline brain."

**The graph** (`create_arteria_graph`):
```
        ┌──────────┐
        │  router  │  (semantic intent classification)
        └────┬─────┘
   conditional edges by intent
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼
 latest bp_  life medi emer hist remi out_ general
 reading analyst style cation gency ory nder scope
   └────┴────┴────┴────┴────┴────┴────┴────┴──► END
```
- `AgentState` is a `TypedDict` carrying everything through the graph (input, user_id, intent, entities, bp_reading, tool calls/results, response, is_emergency, etc.).
- `router_node` corrects medical terms, **pre-gates** unsupported external-data actions (e.g. "email my readings to my doctor" → out_of_scope refusal *before* any tool runs), loads Firebase context, extracts user age, then calls the semantic classifier and routes.
- Each terminal node generates a TTS-clean response and goes to `END`.

**`classify_bp()` — the deterministic clinical core (memorise the thresholds):**
```
Hypertensive Crisis : systolic >180  OR  diastolic >120   (EMERGENCY)
Stage 2 Hypertension: systolic ≥140  OR  diastolic ≥90
Stage 1 Hypertension: systolic ≥130  OR  diastolic >80
Elevated            : systolic ≥121  AND diastolic <80
Hypotension         : systolic <90   OR  diastolic <60
Normal              : everything else (incl. 120/80)
```
- **Age-adjustment:** for users 65+ (`is_elderly`), the Stage-1 systolic threshold is relaxed from 130→135 and the Elevated threshold from 121→135 — reflecting that mild systolic elevation is more tolerated in older adults. Returns `age_adjusted: True` so the response can mention it.
- Returns a dict: `category`, `severity` (good/warning/elevated/high/critical/low), `is_emergency`, `tts_description`, `age_adjusted`.

**`_prepare_response_for_tts()`** — the speech-sanitiser: strips markdown/JSON/emojis, expands `mmHg`→"millimeters of mercury", converts `120/80`→"120 over 80", turns bullet lists into spoken connectives ("Also,…"), and enforces sentence casing/punctuation. French-aware (→ "sur", "millimètres de mercure").

**`_clean_thinking_tags()`** — removes Qwen-3's `<think>…</think>` reasoning blocks from output. (The docstring documents a previously-fixed regex bug — good evidence of iterative debugging.)

**External-data-action detection** (`_is_external_data_action`): structural detection (outbound verb + health-record noun + external channel) to catch "send my blood pressure data to my doctor" — a phrasing no fixed keyword slice would match — and refuse it as out-of-scope. This is a **safety/scope boundary**, not a capability.

### 3.4 `semantic_intent_classifier.py` — multi-strategy intent (1229 lines)

The router's engine. **Five strategies combined** (`classify_intent`):
1. **Entity extraction** — pull BP readings, meds, times up front.
2. **LLM classification** (weight **0.5**) — asks the local model to classify.
3. **TF-IDF semantic similarity** (weight **0.3**) — cosine similarity against a curated bank of ~per-intent example phrases (English + French), vectorised with `TfidfVectorizer(ngram_range=(1,3))`.
4. **Rule-based fallback** (weight **0.2**) — conservative keyword safety-net.
5. **Post-classification guards** — deterministic corrections (e.g. force out-of-scope for unsupported sharing, fix known confusions).

Final intent = `argmax` of the weighted-vote scores, then guards can override. **Why weighted voting?** "No single method is reliable across messy real speech. The LLM is smart but occasionally wild; TF-IDF is stable but literal; rules are safe but rigid. Blending them with the LLM dominant but bounded gives robustness — and the deterministic guards guarantee safety-critical routing regardless of model output."

### 3.5 `mcp_server.py` — the tool layer (710 lines)

Implements a **Model Context Protocol** registry — a clean, typed contract between the LLM and side-effecting database actions.
- `MCPToolRegistry` holds `ToolDefinition`s (name, description, typed `ToolParameter`s). Tools execute via `execute(ToolCallRequest)` → `ToolCallResponse(success, result, error)`.
- Registered health tools: `record_bp_reading`, `add_medication`, `set_reminder`, `get_medications`, `get_bp_history`, `get_user_profile`, `analyze_bp_trend`, `open_whatif_simulator`, `generate_health_report`.
- Exposed over HTTP at `/mcp/tools`, `/mcp/tools/llm`, `/mcp/execute`.

**Why MCP?** "It decouples *deciding* to act from *how* the action touches the database. The orchestrator emits a tool call; the registry validates and executes it against Firebase. It's the same standardised pattern Anthropic introduced for tool use, which makes the action layer auditable and swappable." Note `function_calls` is only populated for *actions* (writes) — read-only lookups are deliberately excluded so the Flutter client doesn't show a false "action completed" toast.

### 3.6 `firebase_context.py` — the data layer (532 lines)

- **Singleton** wrapping Firestore. Reads: profile, `bp_readings`, `medications` (only `isActive==True`), `reminders`, latest BP. Writes: `save_bp_reading`, `add_medication`, `add_reminder`, `deactivate_medication` (soft delete — `isActive=False`, preserving history).
- **`build_user_context()`** assembles a text block (profile + 30-day BP stats + trend arrow + medications + a "missing information" nudge) injected into the LLM prompt. **Cached 60 s per user** (TTL) to avoid 3 Firestore reads every turn; invalidated on any write.
- Collection convention (as used by this backend): `users/{uid}/bp_readings`, `…/medications`, `…/reminders`. Concurrent fetches use `asyncio.gather`. *(Note: the Flutter client may use a `readings` collection name — confirm the two sides agree before the demo.)*

### 3.7 Memory: `conversation_memory.py` + `enhanced_conversation_memory.py`

- **Basic memory** = immutable source of truth: per-session turn list, auto-summarised/trimmed when long, 24 h TTL, used by *every* path to build the prompt.
- **Enhanced memory** = intelligence layer wrapping it: per-message **importance scoring**, entity extraction (BP/meds/symptoms/vitals/sentiment), **trend detection** (linear regression + moving average, combined), proactive-insight generation, and a token-bounded `get_smart_context()`. It's opportunistic — failures are swallowed so they never break a response. Brand→generic medication mapping (e.g. "norvasc"→"amlodipine") normalises drug references.

### 3.8 `voice_sentiment_service.py` — the NOVEL feature (764 lines)

**The thesis's headline innovation.** Estimates psychological stress from the *acoustics* of the user's voice and correlates it with their BP.

Pipeline: Whisper returns word-level timestamps → `librosa` extracts acoustic features → a weighted model produces a 0–100 stress score.

Features → stress mapping (`_calculate_stress_score`):
| Feature | Signal | Weight contribution |
|---------|--------|--------------------|
| Speech rate (WPM) | rushed (>160) = stress; slow = fatigue | `STRESS_WEIGHTS["speech_rate"]` |
| Pitch variation (Hz std) | high = emotional; monotone = fatigue | pitch_variation |
| Pause pattern | frequent hesitations = stress | pause_pattern |
| Energy variation | irregular intensity = instability | energy_pattern |
| Spectral centroid | high (>2000) = tense vocal quality | spectral_features |

The stress score + contributing factors are (a) **injected into the LLM prompt** so the reply adapts tone ("be extra reassuring"), and (b) **saved to Firebase** for longitudinal `get_stress_bp_correlation()` analysis — answering *"does this patient's voice stress track their blood pressure?"* Includes graceful `_fallback_analysis()` returning a neutral result when audio processing fails.

> **Defend the science honestly:** "This is a *screening heuristic*, not a clinical diagnostic. Vocal stress biomarkers are an established research area, but my contribution is integrating them into a BP-monitoring loop — using voice the user is *already* providing — to add an emotional dimension that pure number-logging misses. I validate it as a correlation signal, not a medical instrument."

### 3.9 The supporting agents

- **`proactive_intelligence_agent.py`** — analyses BP trends, medication patterns, lifestyle mentions, and time-of-day patterns to surface up-to-2 `ProactiveInsight`s (with confidence + expiry) the assistant can volunteer. This is what makes Arteria *anticipatory* rather than purely reactive.
- **`medication_optimizer_service.py`** — a curated drug-drug and food-drug interaction database with `InteractionSeverity` (high/moderate/low); detects foods in free text and formats warnings (voice or text).
- **`user_preference_service.py`** — learns each user's preferred `ResponseStyle` (concise/detailed/conversational/clinical) and `HealthLiteracy` level from interaction history, then emits a prompt modifier so responses personalise over time.
- **`medication_lexicon.py`** — single source of truth for medication-name recognition shared by the classifier and the agents (covers ACE inhibitors, ARBs, beta-blockers, CCBs, diuretics, etc.).
- **`telemetry.py`** — OpenTelemetry tracing; no-op unless `OTEL_ENABLED=true`. Produces a span tree per request (http → hybrid → gpt.detect_intent / qwen.query / gpt.generate_response).

### 3.10 The model itself

- Base: **Qwen3-8B**, fine-tuned with **LoRA** adapters on a BP-domain dataset → `TesterColab/Arteria-Qwen3-8B-BP` (adapter) / `…-Merged` (merged weights).
- Served in production via **Ollama** from a **GGUF (f16)** quantisation, configured by the `Modelfile`: `temperature 0.7, top_p 0.9, top_k 40, repeat_penalty 1.1, num_ctx 2048, num_predict 512`, with a ChatML (`<|im_start|>`) template.
- `mac_inference.py` shows the alternative: load Qwen3-8B base on Apple MPS and apply the LoRA adapter with PEFT at runtime.

---

## PART 4 — Worked End-to-End Traces (rehearse describing these aloud)

### Trace A — "My blood pressure was 145 over 92 this morning"
1. `/chat` → Tier 1 hybrid. `build_user_context()` (cached) + history fetched.
2. `GPT.detect_intent()` → `{intent: bp_analysis, entities:{bp_reading:{145,92}}, flags:{}}` (JSON mode).
3. `_handle_bp_analysis`: `validate_bp_reading(145,92)` → valid (systolic>diastolic, in range).
4. MCP `record_bp_reading` writes to Firestore; cache invalidated.
5. `_query_qwen` → `/hybrid/analyze` → Qwen produces medical analysis text.
6. Local `classify_bp(145,92)` → **Stage 2 Hypertension**, severity `high` → sets `flags["abnormal_reading"]=True`, lifts polish prompt into clinical "doctor mode."
7. BP numbers masked → `GPT.generate_response()` writes a doctor-style reply around `<<SYSTOLIC>>/<<DIASTOLIC>>` → real numbers restored.
8. Persisted to both memories; returned with `function_calls` recording the write.

### Trace B — "190 over 120 and my vision is blurry"
1. `detect_intent` → `intent: emergency` (the prompt prioritises emergencies).
2. `_handle_emergency` runs **immediately, no questions**: logs the reading with an EMERGENCY note via MCP, returns a hard-coded calm-but-firm script: *"…indicates a hypertensive emergency. Stay calm, sit down, and call emergency services right away. Do not drive yourself."* `is_emergency:True`.
3. No LLM polish on the safety script — it's deterministic so it can never be softened or garbled.

### Trace C — "add telmisartan" → (next turn) "40 milligrams at 8am"
1. Turn 1: `medication_query/add`, no dose/time → `PendingAction` stored, asks "What's the dosage for telmisartan? For example, 40 milligrams."
2. Turn 2: pending detected first (before new intent detection). Regex extracts `40mg` + `08:00`; both slots filled.
3. `_execute_add_medication` → MCP `add_medication` + auto `set_reminder` at 08:00 daily. Confirmation + structured `medication_feedback` payload for the client toast.

### Trace D — offline ("is my BP okay?", no internet)
1. Tier 1 throws (no OpenAI) → caught → Tier 2 LangGraph.
2. `router_node` → semantic classifier (weighted vote) → `history` intent → `history_node` runs Qwen locally on the user's 30-day stats → TTS-clean reply. **No cloud needed.**

---

## PART 5 — Design Decisions You Must Be Able to Justify

| Decision | Why (the defensible reason) |
|----------|----------------------------|
| **Hybrid GPT + local Qwen, not one model** | Different jobs. Cloud reasoning model excels at messy NL understanding & polish; the fine-tuned local 8B is private, cheap, offline-capable, and domain-specialised for BP analysis. Best of both. |
| **Deterministic `classify_bp()` instead of trusting the LLM** | Patient safety. A clinical category must be reproducible and auditable. LLMs can hallucinate; a 15-line rule function cannot. The LLM only writes *prose around* the Python verdict. |
| **Number-masking placeholders** | LLMs misquote digits. For a medical app, "124 over 74" instead of 124/76 is unacceptable. Python owns the numbers end-to-end. |
| **Three-tier fallback** | Reliability. The app must work on a patient's phone even with no signal. Degrades gracefully, never dark. |
| **Weighted-vote intent classification + guards** | Robustness + safety. Blends three imperfect signals, with deterministic guards for anything safety-critical (scope refusals, emergencies). |
| **MCP tool layer** | Clean, typed, auditable separation between "decide to act" and "touch the database"; standardised and swappable. |
| **Per-user async locks + pending-action expiry** | Correctness under concurrency; stale multi-turn state can't corrupt later conversations (10-min TTL). |
| **60-second Firebase context cache** | Performance. Chat is bursty; without it every turn = 3 Firestore reads. TTL keeps it fresh; writes invalidate it. |
| **Voice as a stress signal** | Novelty + zero extra user burden — it reuses audio the user already speaks, adding an emotional dimension to pure number-logging. |
| **Bilingual (EN/FR) throughout** | Real deployment context (Mauritius/France); language is enforced at the system-prompt level, with native French polish prompts so TTS never code-switches. |

---

## PART 6 — Known Limitations (state these *before* the examiner finds them — it shows maturity)

1. **In-memory state doesn't scale horizontally.** `conversation_memory`, the orchestrator's `_pending` dict, and the context cache live in one process. Two server replicas wouldn't share slot-filling state. *Fix:* externalise to Redis. (Fine for a single-server FYP deployment.)
2. **120/80 is classified "Normal," which is a deliberate softening of strict AHA.** Under strict 2025 AHA/ACC, a diastolic of exactly 80 is the bottom of Stage 1. The classifier treats `≤120/≤80` as Normal to avoid alarming users at the exact boundary — **this is intentional, not a bug.** Note the `api_server.py` system prompt text says "120/80 is Elevated," which contradicts the deterministic classifier; the *deterministic classifier is the source of truth* for the API response, and that's the behaviour to defend. (See PART 7, Q "isn't 120/80 wrong?")
3. **Vocal stress is a heuristic, not a validated clinical instrument.** It's a screening/correlation signal.
4. **Secrets hygiene.** A Firebase service-account JSON and (in `mac_inference.py`) a hard-coded HF token sit in the repo, and CORS is `allow_origins=["*"]`. Acceptable for a local FYP, but I'd move secrets to env/secret-manager and lock CORS for production.
5. **Cloud dependency for best quality.** Tier 1 needs OpenAI + internet; offline mode (Tier 2/3) is good but less fluent.
6. **No formal clinical validation / not a medical device.** The app explicitly *does not diagnose* and always defers to a clinician — a boundary enforced in prompts and in the out-of-scope refusals.

---

## PART 7 — STRICT EXAMINER Q&A (the probing questions)

### A. Architecture & "why did you build it this way?"

**Q1. Why use two LLMs? Isn't that over-engineered and expensive?**
> They do genuinely different jobs. The cloud reasoning model is best-in-class at extracting structure from vague, multilingual, error-laden speech and at producing warm natural prose. The fine-tuned Qwen3-8B is private, runs offline, costs nothing per call, and is specialised on BP-domain data. Using one model means sacrificing either understanding quality or privacy/offline capability. The hybrid gets both, and the local tiers mean the app still works with zero cloud cost when needed. Cost is bounded because GPT calls are short structured JSON + a brief polish, with `reasoning_effort=low`.

**Q2. Walk me through exactly what happens to one message.** → narrate Trace A from Part 4.

**Q3. What if OpenAI is down or the user has no internet?**
> Tier 1 raises, is caught, and the request falls to Tier 2 (LangGraph, fully local Qwen). If LangGraph itself isn't available, Tier 3 makes a direct Ollama call. The user always gets a real answer; only fluency degrades.

**Q4. Where is the "intelligence"? Isn't this just prompt-engineering around an API?**
> The intelligence is in the *orchestration and the safety architecture*, not in any single prompt. Concretely: the deterministic clinical classifier with age-adjustment; the number-faithfulness masking; the multi-turn slot-filling state machine with concurrency locks; the five-strategy weighted-vote intent classifier with deterministic guards; the three-tier degradation; the MCP tool contract; the voice-stress biomarker pipeline. The LLMs are components; the system is the contribution.

**Q5. Why LangGraph *and* the hybrid orchestrator — isn't that duplication?**
> They serve different tiers. The hybrid orchestrator is the cloud-augmented best path; LangGraph is the fully-local fallback with a clean multi-agent structure (router + specialised nodes) that's easy to reason about and runs with no external dependency. Sharing the deterministic core (`classify_bp`, MCP tools, Firebase) means the duplication is only at the routing layer, which is intentional redundancy for reliability.

### B. The LLM / ML substance

**Q6. How did you fine-tune the model? Why Qwen3-8B? Why LoRA?**
> Qwen3-8B because it's a strong open-weight model that fits on consumer/Apple-Silicon hardware and supports a thinking mode I can strip for clean output. LoRA (Low-Rank Adaptation) because full fine-tuning an 8B model is prohibitively expensive and unnecessary — LoRA trains a small set of adapter matrices, giving domain adaptation cheaply, then I merge them and quantise to GGUF f16 for Ollama serving. *(Be ready to discuss your dataset size/source and training params from your training notebooks.)*

**Q7. How do you stop the LLM hallucinating a wrong BP category or a wrong number?**
> Two mechanisms. Categories: a deterministic Python `classify_bp()` is the source of truth for the API; the LLM only narrates it, and the system prompt embeds the rules as a secondary guardrail. Numbers: the masking trick — definite BP values become placeholder tokens before the LLM sees them and are substituted back by Python after, with a retry + scrubber if the model ignores the tokens.

**Q8. Your intent classifier blends three methods with weights 0.5/0.3/0.2 — how did you choose those, and is the argmax-of-weighted-confidence sound?**
> The LLM is the strongest single signal so it dominates (0.5); TF-IDF similarity is a stable secondary (0.3); rules are a conservative tie-breaker/safety net (0.2). The weights were tuned empirically against my RQ3 benchmark. I'll concede the scoring is a heuristic blend rather than a calibrated probabilistic ensemble — the deterministic post-classification guards exist precisely to backstop the cases where the blend is wrong on something safety-critical. *(Honest, defensible.)*

**Q9. What's your context window strategy?** 
> History is trimmed to the last ~4–6 turns for prompts; `num_ctx` is 2048 for the Ollama model; enhanced memory produces a token-bounded "smart context" summary rather than dumping raw history; Firebase context is a compact computed summary, not raw documents.

### C. Clinical safety & ethics

**Q10. Isn't 120/80 "Normal" medically wrong?**
> Under strict 2025 AHA/ACC, 120/80 sits at the Elevated/Stage-1 boundary (diastolic 80 is the floor of Stage 1). I made a *deliberate* design choice to treat ≤120/≤80 as Normal to avoid alarming users at the exact threshold, since a single boundary reading isn't clinically actionable and over-flagging erodes trust. The deterministic classifier is the source of truth, and it's consistent and auditable. I'd flag in production that this threshold is a tunable policy decision a clinician should sign off on.

**Q11. This gives medical advice — what about liability and the line with diagnosis?**
> The system explicitly does **not** diagnose or prescribe — that's enforced both in the system prompts and as hard out-of-scope refusals (e.g. "diagnose whether I have hypertension" → refusal). Every clinically significant path ends by recommending a healthcare professional, and emergencies return a deterministic "call emergency services" script. It's a monitoring and education companion, not a medical device.

**Q12. How do you handle a hypertensive emergency?**
> `classify_bp` flags `>180/>120` as `is_emergency`, and the emergency handler runs first, with **no LLM in the loop** for the safety message — it logs the reading and returns a fixed, calm, directive script telling the user to sit down and call emergency services. Determinism here is the point: the most important message in the app can never be softened or hallucinated.

**Q13. Patient data privacy?**
> The medical reasoning model runs locally, so sensitive analysis needn't leave the device/server. Firebase stores per-user data under their UID. *Honest gap:* the service-account key is in the repo and CORS is open — for production I'd use a secret manager, lock CORS, and add auth on the endpoints.

### D. The novel voice-stress feature

**Q14. Is voice-stress detection scientifically valid? Prove it isn't pseudoscience.**
> Acoustic stress markers — speech rate, pitch variability, pause/hesitation patterns, energy and spectral features — are established in affective-computing literature as *correlates* of arousal/stress. I combine them into a transparent weighted 0–100 score with named contributing factors (not a black box), and I treat it as a **screening/correlation signal**, explicitly not a diagnosis. My contribution is integrating it into a BP loop using audio the user already provides, and analysing whether it tracks their BP over time. I validate it as a correlation, and I'd want larger labelled data to calibrate the weights before any clinical claim.

**Q15. What if the audio is noisy or analysis fails?**
> `_fallback_analysis()` returns a neutral result and the feature is skipped — it never blocks the main response. Whisper word-timestamps anchor the speech-rate estimate.

### E. Software engineering

**Q16. How is this tested?** 
> The `DeepEval/` suite defines research questions RQ1–RQ3; RQ3 specifically benchmarks intent-classification / end-to-end *safe task success* across categories (medication, health info, data retrieval, out-of-scope/emergency), with a ≥90% target, and reports statistics — Shapiro-Wilk normality, Mann-Whitney U for model comparisons, confidence intervals, confusion matrices. *(Excluded from this doc per scope, but know it exists.)*

**Q17. Concurrency — two requests from one user at once?**
> Both the orchestrator and `process_message` hold a **per-user `asyncio.Lock`**, serialising the read-modify-write of multi-turn state so a phantom retry can't corrupt slot-filling.

**Q18. Why FastAPI? Why async?**
> The workload is I/O-bound (LLM HTTP calls, Firestore, TTS) — async lets one process handle many concurrent users without thread overhead. FastAPI gives typed Pydantic validation, automatic OpenAPI docs, and native async + SSE streaming.

**Q19. How do you observe/debug it in production?**
> OpenTelemetry spans (`telemetry.py`) produce a per-request trace tree (intent detection → tool calls → Qwen query → polish) exportable to Jaeger/Tempo, plus structured `[ROUTER]`/`HYBRID:` logs. No-op when disabled, so zero overhead by default.

### F. Killer "gotcha" questions

**Q20. If I removed GPT entirely, would the app still work?** → Yes, Tiers 2/3 are fully local; quality drops, function remains. *(Demonstrates the fallback isn't theoretical.)*

**Q21. Show me the single most clinically dangerous line of code and how you protect it.** → The emergency threshold in `classify_bp` and the emergency handler: deterministic, LLM-free, runs first. The danger is a missed emergency, so it's the most rule-locked path in the system.

**Q22. What would you do differently with another six months?** → Externalise state to Redis for horizontal scale; collect a labelled dataset to *calibrate* the stress-score weights and validate the correlation; add authentication + secret management + locked CORS; formal clinical review of the classification thresholds; expand the eval set and add adversarial/safety red-teaming.

**Q23. What's the weakest part of your system?** → *(Be honest:)* The stress-score weights are hand-set, not learned; the intent-blend weights are empirical; and single-process state limits scale. None affect the safety-critical deterministic core, which is intentional — I put the rigor where the risk is.

---

## PART 8 — Rapid-Fire Glossary (know every term cold)

- **LoRA** — Low-Rank Adaptation; cheap fine-tuning via small adapter matrices instead of updating all weights.
- **GGUF / quantisation** — compact model file format for fast local inference (Ollama); f16 = 16-bit weights.
- **Ollama** — local LLM server exposing `/api/generate`; hosts the "arteria" model.
- **MCP (Model Context Protocol)** — standardised, typed contract for LLM tool/function calls.
- **LangGraph `StateGraph`** — stateful graph of agent nodes with conditional edges; here a router fanning out to specialised handlers.
- **TF-IDF + cosine similarity** — classic text-similarity; matches a query against example phrases per intent.
- **Slot-filling** — collecting missing parameters (dose, time) across multiple turns before executing an action.
- **SSE (Server-Sent Events)** — one-way streaming over HTTP; powers `/chat/stream`.
- **Whisper** — OpenAI speech-to-text; provides word-level timestamps used by the stress analyser.
- **AHA/ACC guidelines** — American Heart Association / American College of Cardiology BP classification standard.
- **Severity tiers** — good / warning(elevated) / elevated(Stage 1) / high(Stage 2) / critical(crisis) / low(hypotension).
- **`reasoning_effort`** — GPT-5-family parameter controlling internal reasoning depth (set to `low` for cost/latency).
- **OpenTelemetry span** — a timed, attributed unit of work in a distributed trace.

---

### How to use this doc this week
1. **Day 1–2:** Read Parts 1–4 until you can *draw the architecture diagram from memory* and *narrate Trace A aloud*.
2. **Day 3–4:** Internalise Part 5 (justifications) and Part 6 (limitations) — examiners reward candidates who name their own weaknesses.
3. **Day 5–6:** Drill Part 7 Q&A out loud; have a friend ask them at random.
4. **Day before:** Skim Part 8 glossary + re-read the `classify_bp` thresholds and the three-tier flow.

**Golden rule in the room:** when unsure, fall back to your strongest, truest sentence — *"GPT owns the words, Python owns the numbers and the clinical decisions, and the system degrades gracefully so a patient is never left without an answer."*
