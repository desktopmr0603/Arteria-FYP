# PART 2 — `api_server.py` DEEP DIVE

## 2.1 Purpose

The single FastAPI application that exposes every backend capability over HTTP. Think of it as a **façade** over the inference engines, memory systems, Firebase, and tool registry.

## 2.2 Imports and feature-flag pattern (lines 13–79)

Every optional subsystem is loaded inside a `try/except ImportError` with a global `_AVAILABLE` flag:

```python
try:
    from hybrid_orchestrator import initialize_hybrid_system, process_hybrid_request
    HYBRID_AVAILABLE = True
except ImportError as e:
    HYBRID_AVAILABLE = False
```

**Why this is good design:** The server starts even if `librosa` (voice sentiment) or `langchain` (LangGraph) isn't installed. Each endpoint then guards on the flag (`if VOICE_SENTIMENT_AVAILABLE`). A senior engineer would call this **graceful degradation at the import level** — a standard production pattern.

**Viva trap:** *"Why not just `pip install` everything and import normally?"* — Because deployment environments differ (raspberry pi vs server), and a single broken dependency shouldn't kill the whole API.

## 2.3 The `SYSTEM_PROMPT` constant (lines 114–144)

This is **prompt engineering as code**. Three things to defend in viva:

1. **Defence-in-depth on classification.** Lines 116-128 hard-code the AHA/ACC 2025 thresholds and explicitly tell the LLM "NEVER classify 130/80 as Normal". *Why?* — LLMs hallucinate. The backend *also* re-classifies deterministically in `langgraph_agents.classify_bp` regardless of what the LLM says. Two layers of defence.

2. **Persona + tone constraints** (lines 138-144). Forces a Siri-like compassionate voice — important because the same model fine-tuned on medical data tends to default to a clinical tone.

3. **No diagnosis disclaimer** ("Always recommend consulting healthcare providers"). This is a **regulatory safeguard** — AI-as-a-medical-device legislation (e.g. EU MDR, FDA SaMD) treats apps that "diagnose" differently from those that "monitor". The disclaimer keeps Arteria in the latter, lighter-touch category.

## 2.4 Pydantic request/response models (lines 151–260)

Pydantic does runtime validation. Look at `BPAnalysisRequest`:

```python
systolic: int = Field(..., ge=50, le=300)
diastolic: int = Field(..., ge=30, le=200)
```

`...` = required. `ge`/`le` enforce physiological ranges. **Defence:** if a Flutter bug sends `systolic=999`, FastAPI returns HTTP 422 *before* the request reaches the LLM — saves money, avoids garbage in. This is a textbook example of **fail-fast at the boundary**.

`OpenAIChatRequest/Response` (lines 207-234) — these mirror OpenAI's API exactly so external clients (e.g., ElevenLabs ConvAI) can hit `/v1/chat/completions` and treat Arteria as a drop-in OpenAI replacement. **Adapter pattern at the protocol level.**

## 2.5 The Strategy Pattern: backend abstraction (lines 263–456)

```python
class BaseBackend:
    async def generate(self, prompt, system_prompt, max_tokens, temperature) -> tuple[str, float]: ...
    async def classify_bp(self, systolic, diastolic, language, user_id) -> tuple[str, bool]: ...

class OllamaBackend(BaseBackend): ...
class TransformersBackend(BaseBackend): ...
```

A canonical **Strategy Pattern**. The CLI flag `--backend ollama|transformers` selects which concrete strategy to instantiate at startup (lines 1676-1680).

**Why two backends?**
- `OllamaBackend` calls `http://localhost:11434/api/generate` — production path. Fast iteration, no GPU memory leaked between requests.
- `TransformersBackend` loads the Hugging Face model directly via `AutoModelForCausalLM` with `device_map="auto"`. Used for benchmarking, since Ollama hides token-level details.

The `_load_model` runs on a thread executor (line 392, `loop.run_in_executor`) because model loading is CPU/GPU-bound and would otherwise block the asyncio event loop.

**Viva line-by-line probe:** *"Why `torch_dtype=torch.float16` and `low_cpu_mem_usage=True` (line 408)?"*
- `float16` halves VRAM and approximately halves inference time on Apple Silicon / NVIDIA GPUs. Quality loss vs `float32` is negligible for chat.
- `low_cpu_mem_usage=True` streams weights to GPU during load instead of materialising the full model in RAM first — critical on a 16GB MacBook.

`OllamaBackend.generate` (lines 307-347) — a few defensive details:
- 60s timeout via `aiohttp.ClientTimeout` → prevents indefinite hang.
- Calls `_clean_thinking_tags` after generation (line 339) because Qwen-3 emits `<think>...</think>` reasoning blocks that must not reach the user.

`generate_with_context` (lines 349-367) injects user context + last 6 messages into the prompt. The number 6 is empirical — large enough for coherent multi-turn, small enough to stay under Qwen's 2048-token context window declared in the Modelfile.

## 2.6 Lifespan management (lines 467–488)

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    await backend.initialize()    # opens aiohttp ClientSession
    if USE_HYBRID: initialize_hybrid_system(...)
    yield
    await backend.shutdown()      # closes session
```

FastAPI's modern lifespan replaces the deprecated `@app.on_event("startup")`. Critical because:
- `aiohttp.ClientSession` must be closed or you leak file descriptors.
- Hybrid orchestrator needs `OPENAI_API_KEY` and the server's own URL (line 479) so it can call its own `/hybrid/analyze` (a self-call pattern).

**Viva trap:** *"Why does the orchestrator HTTP-call its own server instead of importing the function?"*
- Decoupling: same orchestrator can run as a separate service in future.
- The `/hybrid/analyze` endpoint also runs `_prepare_response_for_tts`, `_clean_thinking_tags`, and language enforcement — all of that gets reused for free via HTTP.

## 2.7 CORS middleware (lines 499–505)

```python
app.add_middleware(CORSMiddleware, allow_origins=["*"], ...)
```

`allow_origins=["*"]` is **insecure for production** — anyone can call your API from a browser. **Acknowledge this in viva** as a known limitation: the proper fix is to restrict to your Flutter web origin and Firebase Hosting domain. For an FYP demo it's acceptable.

## 2.8 `/health` endpoint (lines 518-528)

A health-check returning backend status, model name, Firebase availability, and active session count. This is what a load balancer or Kubernetes readiness probe would call.

## 2.9 `/analyze` — the BP-only endpoint (lines 535–606)

Used when the Flutter app already has a structured `(systolic, diastolic, pulse)` triple (e.g. user typed it in via a form, not voice).

Flow:
1. Deterministic classification via `backend.classify_bp` (which itself calls `langgraph_agents.classify_bp`). **No LLM in the loop for the actual classification.**
2. Build user context from Firebase.
3. Generate explanatory text via the LLM.
4. Strip the response for TTS-safety.
5. **Recommendation extraction** by keyword matching (lines 583-590) — naive but robust. If the LLM omits action words like "should", "recommend", a static fallback recommendation is added (line 593).

**Viva critique:** keyword matching is brittle. A more robust approach would prompt the LLM to return JSON with a `recommendations[]` field, but that risks malformed JSON; the keyword scrape always works. **This is a classic correctness-vs-flexibility trade-off** — own it.

## 2.10 `/chat` — the main endpoint (lines 618-802)

This is the **most important endpoint to know cold for viva**.

### Tier 1 (lines 622-668): Hybrid path
- Builds user context + history.
- Calls `process_hybrid_request` (the orchestrator).
- Saves to **both** memory systems (lines 649-657). The `enhanced_memory.add_message` is wrapped in `try/except: pass` — non-critical — so a memory-extraction failure doesn't kill the chat response.

### Tier 2 (lines 671-707): LangGraph path
- Calls `process_message` from `langgraph_agents`.
- **Records adaptive intelligence interaction** (line 681): asynchronous fire-and-forget via `asyncio.create_task`. The user's session ends quickly; preferences update in the background.

### Tier 3 (lines 709-802): Raw Ollama
- Manually fetches **proactive insights from two sources** (lines 729-760):
  - `proactive_intelligence_agent.analyze_user_patterns` — checks for spike trends, missed-medication patterns.
  - `enhanced_memory.get_proactive_insights` — pattern-mining inside the memory store.
- Inserts top-2 insights into the prompt (`prompt_parts.append`).
- Calls the LLM, runs TTS sanitization, persists.

**Why three tiers and not one?**
- *Performance:* Tier 1 is slowest (two GPT calls). Tier 3 is fastest.
- *Privacy:* Tier 2/3 keep the conversation entirely on-device.
- *Reliability:* Each tier is a fallback for the one above.

## 2.11 `/hybrid/analyze` and the dispatch table (lines 813-853)

```python
handlers = {
    "analyze_bp_reading": _handle_bp_analysis,
    "medication_info":    _handle_medication_query,
    "bp_history_analysis": _handle_history_analysis,
    "emergency_assessment": _handle_emergency_check,
    "lifestyle_advice":   _handle_lifestyle_advice,
    "correlation_analysis": _handle_correlation_analysis,
    "risk_assessment":    _handle_risk_assessment,
    "multi_data_analysis": _handle_multi_data_analysis,
    "general_conversation": _handle_general_conversation,
}
```

A **dictionary dispatch** — cleaner than nested `if/elif` and easy to extend. Each handler's signature is *almost* uniform; the conditional on line 841-845 (whether to pass `language`) shows where the abstraction is leaky. A purer design would have all handlers take `language`. Acknowledge this if asked.

### Notable handlers

**`_handle_bp_analysis` (lines 860-919):** if the user gave no values, *fetches their latest reading from Firebase* (lines 868-875). This is what makes "What was my reading?" work without explicit values.

**`_handle_history_analysis` (lines 969-1048):** uses **pre-computed trend data** if the orchestrator already did the work via MCP (line 977). Avoids re-querying Firebase. Falls back to direct Firestore query if not.

**`_handle_emergency_check` (lines 1051-1093):** keyword-based emergency detection (line 1067). **Defence:** the LLM is *not* trusted to flag emergencies; a deterministic list of "chest pain", "blurry vision", etc. acts as a safety net.

**`_handle_correlation_analysis` (lines 1130-1165):** the most intellectually interesting handler — cross-references symptoms × BP averages × medications and asks Qwen for a hypothesis. This is what makes Arteria "feel intelligent" rather than a logger.

## 2.12 `/chat/voice-aware` (lines 1386-1471) — the novel feature

Pipeline (well-commented at lines 1376-1384):
1. Base64 → bytes.
2. Whisper transcription with `include_word_timestamps=True`.
3. **Voice stress analysis** via `voice_sentiment_service.analyze_audio` — extracts speech rate, pitch variation, pause count.
4. **`build_stress_context`** — turns the numerical stress score into prose injected into the LLM prompt ("The user sounds elevated, be reassuring").
5. **Persists analysis to Firebase** for longitudinal stress-vs-BP correlation analysis.
6. Calls LangGraph with `additional_context=stress_context`.

**Session ID is deterministic per user** (line 1394, `hashlib.md5("voice-aware:" + user_id)`). This means voice conversations always reuse the same session, accumulating state across calls. Contrast with text `/chat` where each call may pass its own `session_id`.

**Why MD5?** It's not used as security here — just as a deterministic bucketed key. Faster than UUID + lookup. Acknowledge in viva that MD5 is broken cryptographically but fine for non-security hashing.

## 2.13 `/medication/interactions` (lines 1478-1523)

Calls `medication_optimizer.check_interactions` — a service combining a hard-coded interaction database (e.g. "ACE inhibitors + NSAIDs → reduced efficacy") with food-drug rules ("grapefruit + amlodipine"). Returns a sorted list of `InteractionWarning` with severities.

The endpoint serializes to JSON manually (lines 1500-1512) because `InteractionWarning` is a dataclass with an enum field that doesn't serialize natively.

## 2.14 `/voice/stress-correlation/{user_id}` (lines 1530-1541)

A read-only analytic endpoint: *over the last N days, how does voice stress correlate with BP readings?* Pearson-style correlation done inside the service. Useful for the trends/insights screen in Flutter.

## 2.15 `/speak` and the OpenAI TTS adapter (lines 1548-1600)

`generate_tts` posts `{model, voice, input}` to OpenAI's `/v1/audio/speech` endpoint and returns MP3 bytes. The Flutter app receives raw audio bytes and plays them via `audioplayers`.

**Voice selection logic (line 1556):** if `language == "fr"` and no explicit voice, override with `OPENAI_TTS_VOICE_FR` env var. Cleaner than hard-coding voice names per language.

## 2.16 `/v1/chat/completions` — OpenAI-compatible adapter (lines 1607-1646)

This is what allows tools like ElevenLabs ConvAI, OpenWebUI, or LangFlow to use Arteria as if it were OpenAI. A small but high-leverage feature: **interoperability for free**.

The function pulls the last user message (line 1612-1616) and pipes it through LangGraph or Ollama, then re-wraps the response in the OpenAI envelope shape. Token counts are approximated as `len(text) // 4` — that's the standard *4-chars-per-token* heuristic.

## 2.17 `main()` and CLI (lines 1663-1702)

```python
parser.add_argument("--backend", "-b", choices=["ollama", "transformers"], default="ollama")
```

Standard `argparse`. `uvicorn.run(app, host, port)` starts the server. **Important:** `uvicorn.run(app)` runs in the same process; for production you'd use `uvicorn api_server:app --workers 4` to spawn multiple workers — but multi-worker won't work here because `conversation_memory` is in-process global state. **State sharing across workers would require Redis** — flag this as a known scalability ceiling.

## 2.18 Likely viva questions for `api_server.py`

| # | Question | Strong answer (compressed) |
|---|---|---|
| 1 | Why FastAPI over Django/Flask? | Async-native; LLM I/O is bottleneck; Pydantic validation; auto OpenAPI docs. |
| 2 | What does `lifespan` do that `@app.on_event` doesn't? | Single context manager; runs setup then teardown; recommended since FastAPI 0.93; cleaner exception handling. |
| 3 | Walk me through a `/chat` request from Flutter to response. | (Section 1.4) — three-tier pipeline. |
| 4 | What if Ollama is down? | `OllamaBackend.generate` raises `HTTPException` 500; FastAPI returns it; Flutter shows fallback UI. *Improvement:* could fall back to `TransformersBackend`. |
| 5 | Why two memory systems? | `conversation_memory` = fast prompt history; `enhanced_memory` = entity-aware insight engine; non-critical wraps mean enhanced failure ≠ chat failure. |
| 6 | What's the role of `_prepare_response_for_tts`? | Strips markdown, expands `mmHg`→"millimeters of mercury", removes code blocks, fixes "120/80"→"120 over 80" — voice-friendly. |
| 7 | How do you prevent the LLM hallucinating a "Normal" classification? | Two-layer defence: explicit prompt rules + post-hoc deterministic `classify_bp`. The API response uses the deterministic value. |
| 8 | Why `allow_origins=["*"]`? | Demo; acceptable risk in FYP scope; production fix = whitelist Flutter web + Firebase Hosting. |
| 9 | Why does the hybrid orchestrator HTTP-call its own server? | Service decoupling; reuse of TTS sanitization & language enforcement; ready for future microservice split. |
| 10 | Why fire-and-forget on `user_preference_service.record_interaction`? | Latency: response shouldn't wait for analytics persistence. *Risk:* event loss if process dies; mitigated by infrequency of crashes. |
| 11 | What's the difference between `/analyze` and `/chat`? | `/analyze` = structured BP triple; classification first, LLM explains. `/chat` = freeform NL; LLM understands first, may or may not classify. |
| 12 | If you had to scale to 100k users, what breaks? | In-memory `conversation_memory` (global dict, single process); CORS too permissive; no rate limiting; no auth on endpoints. Fix: Redis sessions + Firebase Auth token verification middleware + Cloud Run with autoscaling. |
| 13 | How is language (en/fr) enforced? | System prompt has explicit "CRITICAL: respond ONLY in French" injection; classification keys are translated; TTS voice is overridden. |
| 14 | Why deterministic session ID for voice-aware chat? | Lets voice conversations accumulate state across separate HTTP calls without the Flutter side managing session IDs explicitly. |
| 15 | Where could prompt injection happen? | User text flows directly into LLM prompts (`f"User: {request.message}"`). A malicious user could try to override the system prompt. **Mitigation:** the system prompt is *prepended* (not interleaved) and the model is instructed via "CRITICAL" flags. *Strict mitigation* would require sanitizing for `<|im_start|>` tokens. |
| 16 | What happens if Firebase is offline? | `firebase_context.is_available` returns False; user_context becomes empty string; LLM still works without personalization. |

## 2.19 Honest weaknesses to be ready to defend

1. **No authentication on endpoints.** Any client can call `/chat?user_id=victim` and read the conversation. *Fix:* verify Firebase ID token in middleware.
2. **No rate limiting.** A loop calling `/chat` would burn OpenAI credits.
3. **`allow_origins=["*"]`.** As above.
4. **In-process state** prevents horizontal scaling.
5. **Recommendation extraction by keyword** is fragile.
6. **MD5 used for session ID** — fine in this context; acknowledge it.
7. **`asyncio.create_task` without `await`** loses errors silently.
8. **No retry logic on Ollama** — transient errors propagate.
