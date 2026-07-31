# PART 7 — Specialized Services

Covers `mcp_server.py`, `voice_sentiment_service.py`, `medication_optimizer_service.py`, `openai_whisper_service.py`, `user_preference_service.py`, `proactive_intelligence_agent.py`.

---

## 7.1 `mcp_server.py` — tool registry

### What is MCP?

**Model Context Protocol** — open standard from Anthropic (late 2024) for LLM-tool integration. Standardizes tool schemas (JSON), invocation (JSON-RPC), responses.

**Why?** Without MCP, every agent duplicates Firebase code. With MCP, tool defined once, any agent uses it via the registry.

### Key types
```python
class ToolParameter(BaseModel)    # name, type, desc, required, enum
class ToolDefinition(BaseModel)   # name, description, parameters, returns
class ToolCallRequest(BaseModel)  # tool, params, user_id, session_id
class ToolCallResponse(BaseModel) # success, result, error, tool, time
```

### MCPToolRegistry

- `register(name, description, parameters, handler, returns)`
- `get_tools_for_llm()` → OpenAI function-calling schema (works for both GPT and Qwen)
- `execute(request)` → looks up handler, awaits, returns timed response

### Registered tools (~10)
get_user_profile, get_bp_history, record_bp_reading, get_medications, add_medication, set_reminder, analyze_bp_trend, get_recent_symptoms, etc.

### `create_mcp_router()` — mounts at `/mcp/*`. External MCP clients can introspect and invoke.

---

## 7.2 `openai_whisper_service.py`

### Singleton pattern
Module functions wrap a single instance; initialized once during FastAPI lifespan.

### `transcribe_audio` flow
```python
form_data = aiohttp.FormData()
form_data.add_field('file', audio_data, ...)
form_data.add_field('model', 'whisper-1')
form_data.add_field('language', language)
form_data.add_field('prompt', medical_prompt)  # ← biasing
```

### `_build_medical_prompt`
Lists common BP medications, dosages, reading formats. **Drops medication misrecognition from 30% to <5%.**

### Word timestamps
`response_format='verbose_json'` + `timestamp_granularities[]='word'` — feeds voice stress analysis.

### `transcribe_with_fallback`
On failure returns canned apology message.

---

## 7.3 `voice_sentiment_service.py` — novel feature

### Why
Most BP apps are passive loggers; this extracts acoustic biomarkers from voice and correlates with BP. **Dissertation contribution.**

### VoiceFeatures (lines 56-67)
9 prosodic features: speech_rate_wpm, pitch_mean_hz, pitch_std_hz, pause_ratio, pause_count, energy_mean, energy_std, spectral_centroid, duration_seconds.

### STRESS_THRESHOLDS / STRESS_WEIGHTS
```python
STRESS_WEIGHTS = {
    "speech_rate": 0.25, "pitch_variation": 0.25,
    "pause_pattern": 0.20, "energy_pattern": 0.15,
    "spectral_features": 0.15,
}
```
Weights sum to 1. Weighted-sum interpretable model.

### `analyze_audio`
1. Load audio bytes via `_load_audio` (WAV detection by magic bytes).
2. `_extract_features` — librosa pitch tracking, RMS energy, spectral centroid, pause detection.
3. `_calculate_stress_score` — each feature gets 0-100 sub-score; weighted sum → final.
4. Bucket: low/moderate/high.
5. Return result with `contributing_factors` strings.

### `build_stress_context`
Turns numeric score into prose:
> "The user is currently exhibiting moderate stress signals: speech is rushed at 175 WPM. Be calm and reassuring."

Injected into LLM prompt — makes voice-aware chat empathetic.

### Persistence
`save_voice_analysis` writes to `users/{uid}/voice_analyses`. `get_stress_bp_correlation` does Pearson-style correlation over N days.

### Fallback
If librosa/numpy unavailable, returns zeros at confidence 0.5.

---

## 7.4 `medication_optimizer_service.py`

### Purpose
Deterministic interaction database for BP medications.

### `BP_DRUG_INTERACTIONS` structure
```python
"lisinopril": {
    "class": "ACE inhibitor",
    "drug_interactions": [{"item": "potassium supplements", "severity": "high", ...}],
    "food_interactions": [{"item": "high-potassium foods", ...}]
}
```

~15 drugs (ACE inhibitors, ARBs, CCBs, beta blockers, diuretics). Hand-curated.

### Severity enum: HIGH / MODERATE / LOW

### `check_interactions(medications, food_mentions, text_input)`
Cross-references user's meds against other meds, foods, and free-text input.

### `format_interaction_warning(warning, for_voice=False)`
Voice format: spoken sentence. Text format: structured.

### Why hard-coded?
Latency, reliability, curation precision. Trade-off: coverage.

---

## 7.5 `user_preference_service.py`

### Purpose
Learns per-user response preferences:
- Verbosity (short/medium/long)
- Detail level (laymen/medical/technical)
- Tone (warm/neutral/formal)
- Follow-up willingness (frequent/occasional/rare)

### `record_interaction(user_id, response_length, had_follow_up, session_duration)`
Fire-and-forget from api_server. Running averages → Firestore.

### `get_preferences(user_id)`
Current profile, sensible defaults if no history.

### `generate_personalized_prompt_modifier(prefs, language)`
Returns string like *"User prefers concise responses... Use warm tone."* — prepended to system prompt.

### No ML
Just running averages + decision rules. Defensible: ML needs more data than a single user provides.

---

## 7.6 `proactive_intelligence_agent.py`

### Purpose
Detects patterns nobody asked about and surfaces them.

### `analyze_user_patterns(user_id, bp_history, medications, conversation_history)`
Runs:
- Time-of-day BP patterns
- Day-of-week patterns
- Adherence patterns
- Symptom recurrence
- Trend acceleration

Returns sorted `List[ProactiveInsight]` with confidence + expiration.

### Ranking
By `confidence × recency × novelty`. Top 1-2 injected. None below 0.6 confidence.

### Graceful failure
api_server wraps in try/except — non-critical.

---

## 7.7 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | What is MCP? | Open standard for LLM-tool integration. |
| 2 | Why central registry? | Single source of truth across agents. |
| 3 | How Whisper handles medical terms? | `prompt` param biases recognition. |
| 4 | What do word timestamps unlock? | Pause + speech-rate for stress analysis. |
| 5 | Walk through voice stress scoring. | 9 features → 0-100 sub-scores → weighted sum → bucketed. |
| 6 | Why hard-code drug interactions? | Latency + reliability + precision. |
| 7 | Drug not in DB? | No warning emitted; UI should not falsely reassure. |
| 8 | Adaptive intelligence without ML? | Running averages + decision rules + prompt modifier. |
| 9 | Wrong proactive insight? | Expiration + ranking; no formal correction. |
| 10 | Voice analysis confidence? | librosa→0.85; fallback→0.5. UI surfaces. |
| 11 | Why split MCP from agents? | Tools do work; agents use them. Like service/controller in MVC. |
| 12 | Cross-user leak? | All tools take user_id; no cross-user data leakage at tool level. |
| 13 | Scale voice sentiment? | Worker queue + batch inference + caching. |
| 14 | Why fire-and-forget interactions? | Latency-critical path. |
| 15 | Dissertation novel contribution? | Voice-stress as second channel; LLM tone adaptation via build_stress_context. |

## 7.8 Honest weaknesses

1. Drug DB small (~15 drugs).
2. Voice stress thresholds population-level (no per-user calibration).
3. Proactive insights not A/B tested.
4. MCP no auth.
5. Whisper prompt EN/FR only.
6. `record_interaction` no retry.
