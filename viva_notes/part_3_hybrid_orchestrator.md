# PART 3 — `hybrid_orchestrator.py` DEEP DIVE

## 3.1 Purpose and one-line summary

This file is the **brain that decides who answers what**. GPT-4o-mini understands the messy human input; Qwen3-8B does the medical reasoning; GPT-4o-mini polishes the final response. It also manages **multi-turn slot-filling** — when the user starts an action (e.g. "add telmisartan") and the next turn supplies the missing info ("40mg at 8am").

**Mental model:** This is a **state-machine-on-top-of-an-LLM**. The "state" is `_pending: Dict[user_id, PendingAction]`.

## 3.2 Why two LLMs instead of one (the central design defence)

This is your biggest architectural decision. Be ready to defend it.

| | GPT-4o-mini | Qwen3-8B (fine-tuned) |
|---|---|---|
| Strength | NL understanding, JSON output | Medical reasoning |
| Cost | $0.15/M tokens (cloud) | Free (local) |
| Latency | ~500-1000ms | ~1-3s on CPU/MPS |
| Multilingual | Excellent | Limited (mostly EN/Chinese) |
| Privacy | Sends data to OpenAI | On-device |
| Hallucination risk | Lower for facts, higher for medical specifics | Lower for medical, higher for general |

**The bet:** a small generalist for understanding + a specialist for the domain task = better than either alone.

**Counter-argument to be ready for:** *"Why not just fine-tune one model to do both?"*
- **Cost:** Fine-tuning Qwen-8B for understanding-AND-classification needs more data and GPU hours.
- **Quality drift:** Fine-tuning on intent classification can degrade medical reasoning ("catastrophic forgetting").
- **Iteration speed:** GPT-4o-mini's prompt is editable in seconds; retraining Qwen takes hours.

## 3.3 Top-level structure (~1730 lines)

```
hybrid_orchestrator.py
├── UserIntent (enum, line 47)
├── IntentResult (dataclass, line 60)
├── PendingAction (dataclass, line 80) — multi-turn state
├── GPTService (line 94) — wraps OpenAI API
│   ├── detect_intent()      — single biggest function (~280 LoC)
│   └── generate_response()  — prose polishing
├── helpers (try_extract_time, try_extract_dosage, validate_bp_reading, correct_medication_name)
├── HybridOrchestrator (line 528)
│   ├── _pending state dict
│   ├── process_user_input()   — main entry
│   ├── process_audio_input()  — wraps text via transcribe
│   ├── _handle_pending_response (slot-filling continuation)
│   ├── 9 intent handlers (_handle_emergency, _handle_bp_analysis, etc.)
│   ├── _execute_add_medication / _execute_medication_switch
│   └── _query_qwen() — internal HTTP to /hybrid/analyze
└── module singletons + initialize_hybrid_system
```

## 3.4 `UserIntent` enum (lines 47-56) — the routing taxonomy

```python
class UserIntent(Enum):
    BP_ANALYSIS         # User gave or asked about a BP reading
    MEDICATION_QUERY    # Add/switch/update/info/interaction
    LIFESTYLE_ADVICE    # Diet, exercise, salt
    EMERGENCY           # >180/120 or critical symptoms
    HISTORY_REQUEST     # Trends, averages, "how have I been"
    LATEST_READING      # Single most-recent reading (NOT a trend)
    REMINDER            # Set/change reminders
    MULTI_DATA          # Multiple things in one message
    GENERAL             # Greetings, fallback
```

**Why `LATEST_READING` and `HISTORY_REQUEST` are separate:** "what was my last reading" and "how has my BP been" sound similar but require different queries — singleton vs aggregate. Splitting them prevents the LLM from blending two different prompts.

## 3.5 `IntentResult` (lines 60-67) — the canonical structured output

```python
@dataclass
class IntentResult:
    intent: UserIntent
    confidence: float
    entities: Dict
    flags: Dict
    actions: List[Dict]
    clarification: Optional[str] = None
    sub_intent: Optional[str] = None
```

This is GPT-4o-mini's **sole interface contract** with the rest of the system. Every downstream handler reads from these fields. **The system prompt (lines 143-277) literally documents this schema** — that prompt *is* the API spec.

**Viva probe:** *"What if GPT returns malformed JSON?"*
- Lines 298-300 wrap `json.loads(raw)` in `try/except`.
- On failure, returns `IntentResult(intent=GENERAL, confidence=0.3, ...)` — **fail-soft**: the user still gets a response, just routed through the generic handler.

## 3.6 `PendingAction` (lines 80-87) — the state-of-the-art bit

```python
@dataclass
class PendingAction:
    action_type: str
    data: Dict[str, Any]
    missing: List[str]
    created_at: float
    
    def is_expired(self, timeout_seconds: int = 600) -> bool:
        return time.time() - self.created_at > timeout_seconds
```

**This is what makes Arteria feel like Siri.** When the user says "add telmisartan", the orchestrator stores `PendingAction(action_type="add_medication", data={"name":"telmisartan"}, missing=["dosage","time"])`. Next turn, "40mg at 8am" satisfies both missing fields. After 10 minutes, the pending action expires (line 86-87) — preventing stale state from corrupting future conversations.

**Where state lives:** `self._pending: Dict[str, PendingAction]` keyed by user_id. **Limitation:** this is in-process state, doesn't survive a server restart. *Production fix:* persist to Redis with TTL.

## 3.7 The `GPTService.detect_intent` system prompt (lines 143-277)

This is a **prompt engineering masterclass**. The structure:

1. **Role declaration** (line 143): "You are a medical assistant intent classifier".
2. **Intent taxonomy** (lines 147-156) — 9 categories with precise distinguishing rules.
3. **Sub-intent taxonomy** (lines 158-167) — finer-grained actions inside `medication_query` and `history_request`.
4. **Flag taxonomy** (lines 170-178) — boolean signals like `vague_values`, `likely_reversed`, `user_anxious`.
5. **Entity schema** (lines 180-191) — what to extract.
6. **Action schema** (lines 193-198) — MCP tool suggestions.
7. **Output format spec** (lines 200-209) — strict JSON.
8. **Few-shot examples** (lines 211-277) — five examples covering vague values, reversed values, switches, multi-data, emergency.

**Why few-shot here?** Even GPT-4o-mini drifts on edge cases. The example for "40 over 200" teaching "likely_reversed" is the kind of thing zero-shot misses.

**Temperature=0.1 (line 299)** — near-deterministic output for classification. Classification randomness would cause the same input to route differently across calls.

## 3.8 `validate_bp_reading` (lines 458-475) — the safety net

```python
if systolic < diastolic: result["issue"] = "reversed"
elif systolic > 300 or diastolic > 200 or systolic < 40 or diastolic < 20:
    result["issue"] = "out_of_range"
elif systolic == diastolic: result["issue"] = "identical"
```

**Why this exists** even though Pydantic already validates ranges:
- Pydantic checks the *structured* `/analyze` endpoint. The hybrid pipeline gets numbers from the LLM extracting them from messy speech, so a second physiological-plausibility check is needed.
- `systolic < diastolic` is impossible *physiologically* but Pydantic doesn't know that — it's a cross-field invariant.

**Defensive programming principle:** validate at every layer of trust crossing.

## 3.9 `correct_medication_name` and the medication lexicon (lines 478-521)

```python
MEDICATION_CORRECTIONS = {
    "tell me jordan": "telmisartan",
    "tell me sartan": "telmisartan",
    "am low depine": "amlodipine",
    "lysine oh pril": "lisinopril",
    ...
}
```

These are **real Whisper transcription errors** for foreign-sounding generic names. The fuzzy match (line 513-519) uses `difflib.SequenceMatcher` with a 0.7 ratio threshold against `KNOWN_MEDICATIONS`.

**Trade-off in viva:** *"Why not use a proper drug database (RxNorm, FDA)?"* — Latency and complexity. `SequenceMatcher` is in stdlib, instant. Acceptable for the 20 most-common BP meds. Production would integrate RxNav for the long tail.

## 3.10 `HybridOrchestrator.process_user_input` (lines 568-625) — the master flow

```python
async def process_user_input(self, user_input, user_id, conversation_history, user_context, language):
    # Step 0: Are we mid-conversation? (slot-filling)
    pending = self._get_pending(user_id)
    if pending:
        result = await self._handle_pending_response(...)
        if result: return result

    # Step 1: GPT detects intent + extracts entities
    intent_result = await self.gpt.detect_intent(user_input, conversation_history, language)

    # Step 2: Dispatch to the right handler
    handler = handler_map[intent_result.intent]
    result = await handler(user_input, user_id, intent_result, user_context, language)
    
    return result
```

**Three things to know cold:**
1. **Pending check is first.** This means if the user has an open follow-up, the orchestrator handles it *before* re-running intent detection.
2. **Conversation history is passed to intent detection** (line 595).
3. **Each handler returns a `Dict` with shape `{type, response, function_calls, ...}`.**

## 3.11 `_handle_pending_response` slot-filling (lines 658-808)

Three flavours:

### `_continue_add_medication` (lines 683-720)
Pulls dosage + time from any text via `try_extract_dosage` / `try_extract_time`. If neither found *and* the input has no relevant signal, assumes the user changed topic and clears pending. **Graceful state recovery** — user can't get stuck in a loop.

### `_continue_switch_medication` (lines 722-754)
Same pattern but tracks `new_dosage` and `new_times`.

### `_continue_clarify_bp` (lines 756-808)
Re-validates the corrected reading; if still invalid, gives up. Synthesizes a "fake" `IntentResult` and re-enters `_handle_bp_analysis` — reuse via fabrication.

## 3.12 `_handle_emergency` (lines 814-854) — the safety-critical handler

```python
if s and d and MCP_AVAILABLE:
    notes = f"EMERGENCY - symptoms: {', '.join(symptoms)}"
    await mcp_registry.execute(ToolCallRequest(tool="record_bp_reading", ...))
```

The reading is **logged before responding**. Then the response is hard-coded prose — *no LLM in the emergency path*. **Why?** Predictability. The emergency message must always be the same and never hallucinate.

## 3.13 `_handle_bp_analysis` (lines 856-995) — the most complex handler

Five branches:

1. **Suspicious / reversed values** — set pending=clarify_bp, ask user.
2. **Vague values** — pass GPT's clarification through.
3. **Multiple readings** — loop, validate, log, Qwen-analyze each, GPT combine.
4. **No reading present** — ask the user.
5. **Single valid reading** — record + Qwen analyze + GPT polish.

The **two-LLM pattern** is visible in step 5: `_query_qwen` then `gpt.generate_response`.

## 3.14 `_handle_medication` (lines 997-1084) — the most-used handler

Sub-intent dispatch:
- `switch` → ask for new dosage, set pending.
- `add` → call `_handle_add_medication`.
- `update` → fetch existing med, change dosage, keep timing.
- `interaction` → query Qwen for analysis.
- `info` (default) → MCP `get_medications` → GPT polish.

**Note line 1019:** "Different drugs need different dosages, so always ask" — even if user didn't volunteer a dosage during a switch, force asking. Safety feature.

## 3.15 `_handle_history` (lines 1288-1353)

Sub-intent decides which `/hybrid/analyze` action to trigger. Always fetches `analyze_bp_trend` from MCP first, then passes pre-computed averages to Qwen. **Performance:** keeps trend questions under 5s end-to-end.

## 3.16 `_handle_multi_data` (lines 1436-1511) — showpiece feature

For input like *"BP was 135/88, took amlodipine, had a headache, skipped my walk."*

1. Validate + record BP with notes including symptoms and lifestyle.
2. Track which data points were extracted.
3. Call Qwen with all data points.
4. GPT polishes into a single coherent response.

**This is the killer feature for the demo.**

## 3.17 `_query_qwen` (lines 1644-1666) — the internal HTTP call

```python
async with aiohttp.ClientSession() as session:
    resp = await session.post(f"{self.qwen_url}/hybrid/analyze", json={...}, timeout=30)
```

1. **30s timeout** — Qwen can be slow on CPU.
2. **New ClientSession per call** — wasteful. Improvement: singleton session.
3. **Errors return `{error, fallback}`** — never throws.

## 3.18 `process_hybrid_audio` (lines 631-652)

Just transcribe-then-text-process. Returned dict carries `transcription` so Flutter can display what Whisper heard.

## 3.19 Module-level singleton (lines 1701-1731)

```python
hybrid_orchestrator: Optional[HybridOrchestrator] = None
def initialize_hybrid_system(openai_api_key, qwen_service_url):
    global hybrid_orchestrator
    initialize_whisper_service(openai_api_key)
    hybrid_orchestrator = HybridOrchestrator(openai_api_key, qwen_service_url)
```

Module singleton called once during FastAPI lifespan.

## 3.20 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | Why two LLMs? | Separation of concerns + cost + privacy + iteration speed. |
| 2 | Walk me through "I switched from telmisartan to lisinopril and need to know the dose". | GPT detects intent=medication, sub=switch; `_handle_medication` sets pending=switch_medication; next turn extracts "40mg"; `_execute_medication_switch` calls MCP; confirms verbally. |
| 3 | What stops the LLM from making up medication interactions? | `medication_optimizer_service` has hard-coded interaction tables; LLM prompt is conservative + says "consult your doctor". |
| 4 | What if GPT returns invalid JSON? | `try/except` returns IntentResult(GENERAL, conf=0.3) → falls into generic handler. |
| 5 | Why temperature=0.1 for intent and 0.7 for generation? | Classification needs determinism; generation needs warmth. |
| 6 | How is multi-turn state managed without a database? | In-process Dict, 10-min TTL. Lost on restart — production fix is Redis. |
| 7 | Why hard-code emergency response text? | Predictability; LLM hallucination on critical-care path is unacceptable. |
| 8 | What's the role of `correct_medication_name`? | Whisper mis-hears foreign generic names; fuzzy match before MCP call. |
| 9 | What's `validate_bp_reading` for given Pydantic? | Cross-field invariant; LLM-extracted numbers Pydantic never sees. |
| 10 | Could a malicious user inject prompts? | Yes — mitigation: GPT asked for structured JSON only; injection corrupts JSON → fail-soft path. |
| 11 | Why does intent detection see conversation history? | Disambiguates short follow-ups: "yes" or "the second one" need context. |
| 12 | Why is pending action timeout 10 minutes? | Long enough for natural pauses, short enough to avoid stale state. |
| 13 | Could `process_user_input` deadlock? | No — every coroutine awaits an HTTP call with finite timeout. |
| 14 | What makes the multi_data flow hard? | Combining heterogeneous extracted entities into a single coherent response. |
| 15 | What would you change if redoing this? | Persist `_pending` to Redis; reuse aiohttp session; retry-with-backoff; OpenTelemetry tracing. |

## 3.21 Honest weaknesses

1. **State is in-memory** — restart loses pending actions.
2. **`async with aiohttp.ClientSession()` per call** — small inefficiency.
3. **Dispatch table mixes signature shapes** — minor design smell.
4. **No retries** on Qwen or GPT failures.
5. **Medication corrections are hard-coded** — won't scale.
6. **No telemetry** — hard to debug production issues.
7. **`detect_intent` JSON parsing trusts GPT** — no schema validation.
