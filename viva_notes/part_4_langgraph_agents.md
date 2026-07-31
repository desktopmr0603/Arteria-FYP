# PART 4 — `langgraph_agents.py` DEEP DIVE

The largest file at ~170 KB, ~3700 lines.

## 4.1 Purpose

This is **Tier 2** of the three-tier pipeline. When the hybrid (GPT+Qwen) system can't run, this LangGraph multi-agent system takes over, using **only Qwen3-8B locally**. It has 9 specialized agents, deterministic medication sub-intent classification, retrieval-grounding rules, out-of-scope refusal logic, and educational-fallback prompts.

## 4.2 What is LangGraph and why use it?

**LangGraph** provides a typed StateGraph primitive: nodes are agent functions reading/writing shared `TypedDict` state; edges (including *conditional edges*) define routing.

**Why pick LangGraph over plain function chaining or LangChain `Chain`?**
- **Cyclic flows** — chains are DAGs; StateGraph supports loops.
- **Centralized state** — every node sees the same dict.
- **Visualization** — graphs can be rendered.
- **Failure handling** — each node independently catchable.

## 4.3 The `AgentState` TypedDict (lines 492-527)

The single source of truth shared across all agents. Contains input fields, context, extracted data, sub-intent tracking, tool calls, output fields, and metadata.

**Viva probe:** *"Why TypedDict and not Pydantic?"* — LangGraph uses TypedDict natively. Pydantic adds runtime cost; static typing is sufficient.

## 4.4 The graph topology (lines 3578-3643)

```
                    ┌──────────────┐
                    │    router    │
                    └──────┬───────┘
                           │ route_by_intent (conditional edge)
       ┌─────────┬─────────┼─────────┬─────────┬──────────┐
       ▼         ▼         ▼         ▼         ▼          ▼
  bp_analyst lifestyle medication emergency history reminder ...
       │         │         │         │         │          │
       └─────────┴─────────┴─────────┴─────────┴──────────┘
                           │
                          END
```

- **Entry:** `router_node`.
- **Conditional edge:** `route_by_intent(state)` returns next-node name.
- **Terminal:** every leaf has `add_edge(node, END)`.

**No loops** — single-pass per turn. Multi-turn state held *outside* the graph in module-level dicts.

## 4.5 The `Intent` enum (lines 369-381)

11 intent values, 9 nodes (`CONVERSATION` and `RECOMMENDATIONS` collapse into `GENERAL` — refactor artifact).

## 4.6 `MedicationSubIntent` (lines 384-392)

```
RECORD_ADD              # "I started taking telmisartan 40mg"
RECORD_UPDATE           # "I switched from amlodipine to losartan"
INFORMATION_QUERY       # "Can I take lisinopril with grapefruit?"
MISSED_DOSE             # "I forgot my BP pill this morning"
DOUBLE_DOSE_OVERDOSE    # "I accidentally took a double dose"
STOP_MEDICATION         # "Should I stop taking this?"
```

**Why a separate sub-intent system?** Medication is the most safety-critical: missed-dose vs double-dose vs stop-medication need *very different* responses.

`classify_medication_subintent` (lines 570-707) uses **deterministic keyword heuristics ordered by safety priority**:

```
1. Double-dose / overdose   ← safety-critical, checked FIRST
2. Missed dose
3. Stop medication           ← safety-critical, before update
4. Update / switch
5. Information / interaction query
6. Default: record_add
```

**Check the most dangerous category first** so it can't be misrouted.

## 4.7 Response policy constants (lines 399-489)

Static strings for:
- `MEDICATION_SAFETY_DISCLAIMER`
- `EMERGENCY_GUIDANCE` (with 911/999/112/SAMU numbers)
- `OOS_REFUSAL` / `OOS_MEDICAL_REFUSAL`
- `RETRIEVAL_GROUNDING_INSTRUCTION`
- `EXTERNAL_DATA_ACTION_REFUSAL`

**Why constants?** Safety-and-compliance text reviewed once, trusted forever. **Policy-as-data.**

## 4.8 `classify_bp` (lines 844-935)

Implements 2025 AHA/ACC guidelines:
- Hypertensive Crisis: sys > 180 OR dia > 120
- Stage 2: sys ≥ 140 OR dia ≥ 90
- Stage 1: sys ≥ 130 OR dia > 80 (≥135 if elderly)
- Elevated: sys ≥ 121 AND dia < 80 (≥135 if elderly)
- Hypotension: sys < 90 OR dia < 60
- Normal: everything below

**Age adjustment** (`is_elderly = age ≥ 65`): elderly tolerate slightly higher BP.

**Why deterministic?** A misclassification could lead the LLM to omit lifestyle advice. Single source of truth, called from api_server.py, hybrid_orchestrator, and bp_analyst_node.

## 4.9 `_is_external_data_action` (lines 961-1009)

Detects "send my BP to my doctor" type requests. Uses structural heuristic:

```
[outbound verb] + [health-record noun] + ([outbound channel] or report type)
```

Catches phrasings fixed substrings would miss. Has internal-viewing exception ("show me my readings" allowed). Used as **router pre-gate** — refuses unsupported actions before they reach a tool-calling agent.

## 4.10 `correct_medical_terminology` (lines 771-817)

Two-step:
1. **Direct lookup** in MEDICATION_CORRECTIONS (40+ phonetic mishearings).
2. **Fuzzy match** of n-grams via `difflib.SequenceMatcher`, threshold 0.75.

Skips phrases with digits to avoid mangling dosages.

## 4.11 `router_node` (lines 1016-1156)

Steps:
1. correct_medical_terminology
2. _is_external_data_action → OUT_OF_SCOPE early-return
3. Build user_context, extract user_age from Firebase
4. semantic_classifier.classify_intent → Intent + entities
5. **Pending-medication carry-over** (Strategy 1 server state + Strategy 2 history scan)
6. Emergency early-return
7. Return state

**Pending detection** (lines 1083-1120) uses both server-level dict and conversation-history pattern match — belt-and-braces.

**Fallback** if classifier crashes: regex BP extract + emergency check + default GENERAL.

## 4.12 `bp_analyst_node` (lines 1241-1325)

Five-step:
1. If no BP, fetch latest from Firebase.
2. If still none, ask the user.
3. `classify_bp(...)` deterministic.
4. Record via MCP `record_bp_reading`.
5. LLM generates explanation; prompt explicitly forbids changing classification.

## 4.13 `lifestyle_node` (lines 1328-1588)

**Static templates for established topics** (exercise, salt, weight, diet, stress, alcohol, caffeine, supplements). Why? Established medical evidence (DASH diet → 8-14 mmHg drop) — static is more accurate and faster than LLM.

**LLM fallback** for educational health-info queries with 8 explicit response requirements + `validate_health_response` quality gate.

## 4.14 `emergency_node` (lines 1590-1660)

Three responsibilities:
1. **Always include limitation statement** ("I am not able to provide medical treatment...").
2. **Branch on real BP reading.** If yes, hypertensive-crisis text. If no, **never fabricate numbers** — generic emergency guidance with localized phone numbers.
3. Numbers (911/999/112/SAMU 15/18) localized.

## 4.15 `medication_node` (lines 2574-2618)

Sub-intent dispatch table to 6 handlers. Same pattern as `/hybrid/analyze`.

Notable handlers:
- **`_medication_record_add_handler`** (~325 lines): slot-filling, dosage validation, time extraction, MCP execution, reminder creation.
- **`_double_dose_handler`**: never recommends action; redirects to poison control.
- **`_stop_medication_handler`**: never advises stopping; redirects to doctor.

## 4.16 `history_node` (lines 3125-3255) — retrieval-grounded

1. Classify query type (`average` / `latest` / `highest` / `lowest` / `count` / `trend` / `comparison` / `threshold` / `consistency` / `summary`).
2. Determine `period_days`.
3. Call MCP `get_bp_history` and `analyze_bp_trend`.
4. Validate retrieval (`_validate_retrieval_tools`).
5. **Format from fixed templates** — no LLM in the loop.

10+ formatter functions. **Entire pipeline LLM-free for trends** — hallucinated numbers are unacceptable.

## 4.17 `out_of_scope_node` (lines 3325-3410)

Distinguishes:
- Pure out-of-scope ("what's the weather?")
- Medical out-of-scope ("diagnose me")
- External data action

Returns one of three static strings.

## 4.18 `general_node` (lines 3411-3539)

Catch-all for greetings, fallback, edge cases. Calls Qwen with Siri-like prompt. Closest to a raw chat path.

## 4.19 `process_message` (lines 3654-3728)

Public entry point. Generates session_id, persists user message, builds initial state, invokes `arteria_graph.ainvoke(initial_state)`, persists response, returns dict with response + metadata.

**Single LLM round-trip per turn maximum** (vs hybrid's two).

## 4.20 `_fallback_process` (lines 3731-3764)

If LangGraph not available, regex BP extract + classify + canned text. Bare-minimum survival mode.

## 4.21 TTS helpers (lines 110-212)

- `_clean_thinking_tags`: removes Qwen-3 `<think>` blocks.
- `_prepare_response_for_tts`: strips markdown, expands units, normalizes numbers, removes emojis, capitalizes.

## 4.22 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | What is LangGraph? | StateGraph primitive — typed shared state, conditional edges, supports cycles. |
| 2 | Walk me through the graph topology. | router → conditional edge → one of 9 leaf nodes → END. |
| 3 | Why is medication a single node with sub-intents? | Shared slot-filling logic; safer to consolidate. |
| 4 | Why is the history node LLM-free? | Hallucinated numbers are unacceptable; templates ensure exact retrieved values. |
| 5 | How does the router prevent prompt injection for external data sharing? | `_is_external_data_action` structural pre-gate. |
| 6 | What does `classify_medication_subintent` use? | Ordered keyword heuristics (double-dose first, then missed, etc.). |
| 7 | What if semantic classifier fails? | Regex BP extraction fallback. |
| 8 | How is multi-turn medication state handled? | Module-level dict, 10-min TTL. |
| 9 | Why two strategies for pending detection? | Belt-and-braces: server state + history scan. |
| 10 | How is response made TTS-safe? | `_prepare_response_for_tts` strips markdown, expands units. |
| 11 | How is BP classification kept consistent? | Deterministic `classify_bp` + LLM prompt forbids changing it. |
| 12 | Role of `_clean_thinking_tags`? | Strips Qwen-3 reasoning blocks. |
| 13 | If LangGraph isn't installed? | `_fallback_process` simulates a one-node graph. |
| 14 | Age-adjusted classification? | Stage 1/Elevated thresholds raised by 5 mmHg if age≥65. |
| 15 | "Diagnose my chest pain"? | Marks OUT_OF_SCOPE; `out_of_scope_node` returns medical refusal. |
| 16 | Why TypedDict not Pydantic? | LangGraph native; no runtime cost. |
| 17 | Why static lifestyle templates? | Well-established evidence; LLM produces variable phrasings; static safer. |
| 18 | Race conditions on pending dict? | Possible — no lock. Fix: per-user asyncio.Lock. |
| 19 | French support? | `state["language"]` propagates; classifier handles French keywords; every branch has FR/EN. |
| 20 | Role of `validate_health_response`? | Quality gate; rejects too-short or template-echo responses. |

## 4.23 Honest weaknesses

1. **No concurrency control** on `_pending_medication_by_user`.
2. **All-static topology** — adding agents requires changes in 4 places.
3. **`process_message` doesn't stream** — user waits for full response.
4. **Hard-coded medication corrections** don't scale.
5. **Intent values collapse to nodes** — cleanup smell.
6. **No graph checkpointing** — relies on external state dicts.
