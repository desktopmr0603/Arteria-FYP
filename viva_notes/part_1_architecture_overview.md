# PART 1 — BACKEND ARCHITECTURE OVERVIEW (`QwenArteria/`)

## 1.1 What this project actually is

**Arteria** is a voice-first blood pressure monitoring assistant. The architecture is genuinely novel for an FYP because it implements a **hybrid LLM orchestration pattern**: a *cloud* model (GPT-4o-mini) handles natural-language understanding while a *locally-hosted* fine-tuned medical model (Qwen3-8B, served via Ollama) handles medical reasoning. This is not a generic ChatGPT wrapper.

## 1.2 Technology stack and why each piece exists

| Layer | Technology | Why this choice |
|---|---|---|
| API framework | **FastAPI + Uvicorn (ASGI)** | Async-native, automatic Pydantic validation, OpenAPI docs free. Required because LLM calls are I/O-bound — sync Flask would block. |
| Local LLM serving | **Ollama** running custom `arteria` model | Ollama wraps `llama.cpp` for GGUF quantized inference. Lets a 8B-parameter model run on a MacBook in fp16 via Metal Performance Shaders. |
| Base model | **Qwen3-8B**, fine-tuned via LoRA, merged, then quantized to GGUF (`arteria-bp.f16.gguf`) | Qwen has strong instruction-following and an Apache 2.0 licence; 8B is the largest size that runs interactively on consumer hardware. |
| Cloud LLM | **GPT-4o-mini** | Used only for intent classification + response polishing; cheap (~$0.15/M tokens), fast, multilingual EN/FR. |
| Speech-to-text | **OpenAI Whisper** (`whisper-1` API) | Replaced earlier RunPod WhisperV3 deployment — cheaper and supports word-level timestamps needed for stress analysis. |
| Text-to-speech | **OpenAI TTS** (`tts-1`) | Replaced ElevenLabs/Kokoro to consolidate vendor surface and reduce latency. |
| Database | **Firebase Firestore** | Document store fits irregular medical data (varying medication schedules, optional fields). Firebase Auth is shared with Flutter. |
| Multi-agent orchestration | **LangGraph** (StateGraph) | Provides typed cyclic state machines — cleaner than raw conditional chains in LangChain. |
| Tool execution | **MCP (Model Context Protocol)** custom registry | Decouples tool schemas from agent code; MCP is becoming a standard. |
| Voice biomarkers | **librosa + scipy** | Extracts pitch, jitter, speech rate from waveform for stress classification. |
| Embeddings/similarity | **scikit-learn TF-IDF + cosine** | Used by `semantic_intent_classifier.py` for fallback intent matching. Avoids the dependency weight of sentence-transformers. |

## 1.3 The three-tier degradation strategy

`api_server.py:618-802` (the `/chat` endpoint) implements **graceful degradation**:

```
Tier 1: Hybrid (GPT + Qwen)   ← best UX, requires internet + OPENAI_API_KEY
   ↓ fallback on exception
Tier 2: LangGraph + Qwen only  ← runs offline, multi-agent reasoning
   ↓ fallback if LangGraph unavailable
Tier 3: Direct Ollama call     ← bare-bones; system prompt only
```

**Why this matters for viva:** *"What happens if your OpenAI key is rate-limited mid-conversation?"* — Tier 2 catches it; the user never sees an error.

## 1.4 The hybrid request lifecycle (most-asked viva question)

For a message like *"My BP was 140 over 90 and I have a slight headache"*:

```
1. Flutter (Dio HTTP client)
   POST /chat { user_id, message, language }
        ↓
2. api_server.py:619 (chat endpoint)
   ├── fetch user context from Firebase  (firebase_context.build_user_context)
   ├── fetch conversation history        (conversation_memory)
   └── delegate to hybrid_orchestrator.process_user_input
        ↓
3. hybrid_orchestrator.GPTService.detect_intent
   GPT-4o-mini returns structured JSON:
   { intent: "multi_data", entities:{bp_reading:{140,90}, symptoms:["headache"]} }
        ↓
4. handler dispatch → _handle_multi_data
   POST http://localhost:8000/hybrid/analyze   ← internal HTTP call to Qwen
        ↓
5. Qwen3-8B (via Ollama) returns medical analysis
        ↓
6. hybrid_orchestrator.GPTService.generate_response
   GPT-4o-mini polishes the technical analysis into warm conversational prose
        ↓
7. response saved to conversation_memory + enhanced_memory
        ↓
8. JSON returned to Flutter
```

**Two LLM round-trips per turn** — that is the cost of the hybrid pattern, ~2-3 s extra latency.

## 1.5 Memory subsystems

There are **two parallel memory systems** running side-by-side — this is intentional, not redundant:

1. **`conversation_memory.py`** — In-memory `OrderedDict` of sessions, max 1000 sessions, 24-hour TTL, LRU eviction. Stores raw turn-by-turn history. Fast, ephemeral.
2. **`enhanced_conversation_memory.py`** — Layered memory with **entity extraction**, semantic indexing, temporal patterns, and proactive insight generation. Uses LLM-assisted extraction (`add_message_async`).

`api_server.py:649-657` shows both being written on every turn. The simple one is the source of truth for the prompt; the enhanced one feeds proactive insights.

## 1.6 Configuration (`api_server.py:85-104`)

Two boolean feature flags drive the whole pipeline:

- `USE_LANGGRAPH=true` — enables Tier 2
- `USE_HYBRID=true` — enables Tier 1

If both are off, the system collapses to Tier 3 (raw Ollama). This was deliberate: it lets you A/B compare quality without code changes.
