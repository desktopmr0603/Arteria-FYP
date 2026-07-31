# PART 6 — Conversation Memory + Firebase Context

## 6.1 Why two memory systems coexist

Two parallel implementations:
- `conversation_memory.py` (242 lines) — base layer, immutable source of truth
- `enhanced_conversation_memory.py` (~1000 lines) — intelligence layer with semantic indexing, importance scoring, pattern recognition

**Layered abstraction.** Basic = reliable (drives prompts). Enhanced = best-effort (drives proactive insights). Enhanced failures must not break chat.

---

## 6.2 `conversation_memory.py`

### Message dataclass
```python
@dataclass
class Message:
    role: str
    content: str
    timestamp: float
    metadata: Dict
```

### ConversationSession (lines 41-139)
- `max_messages=50`, `max_context_tokens=4000`
- `add_message`: append + auto-trim
- `_summarize_and_trim`: keep last 10 verbatim, summarize last 5 of dropped ones as system message at top
- `get_messages_for_prompt`: format for LLM
- `get_context_string`: user_context + last 6 messages

### ConversationMemory class (lines 142-237)

LRU+TTL cache via OrderedDict:
- `move_to_end` on access marks as recently used
- `popitem(last=False)` evicts oldest when over cap (1000 sessions)
- `_cleanup_old_sessions` drops >24h old

**Single-worker only** — multi-worker corrupts state, would need Redis.

---

## 6.3 `enhanced_conversation_memory.py`

### Static knowledge bases

- **MEDICATION_DATABASE**: generic → list of brand names. Pre-computed flat sets (`ALL_MEDICATION_NAMES`, `BRAND_TO_GENERIC`) for O(1) lookup. Norvasc → amlodipine.
- **SYMPTOM_DATABASE**: phrase → clinical category. `_emergency` suffix triggers emergency flag.
- **WORD_NUMBERS**: spoken-number map for "one forty over ninety" → 140/90.

### MemoryFragment (lines 113-136)

```python
@dataclass
class MemoryFragment:
    content: str
    role: str
    importance: float    # 0.0 to 1.0
    category: str        # bp_reading, medication, lifestyle, personal, general
    timestamp: float
    entities: Dict
```

**`importance` is the key idea.** BP 180/120 → ~1.0; "Hi" → ~0.3. Eviction prioritizes low-importance.

### ConversationInsight (lines 139-152)

```python
@dataclass
class ConversationInsight:
    insight_type: str    # trend, concern, recommendation
    content: str
    confidence: float
    expires_at: Optional[float]
```

**Insights expire** to avoid stale repeated mentions.

### Entity extraction (lines 163-300+)

`extract_entities(content)`:
- `_extract_bp_reading`: 4 formats including spoken
- `_parse_spoken_bp` + `_words_to_number`: number-word parser
- `_extract_medications`: word-boundary regex against ALL_MEDICATION_NAMES
- `_extract_symptoms`: phrase scan; emergency flag if any `_emergency` category
- `_extract_vitals`, `_extract_sentiment`, `_classify_intent`

### LLM fallback

`add_message_async` calls LLM to extract entities regex missed. Tier 3 only. Non-blocking.

### Smart context

`get_smart_context(user_id, session_id)` builds context string prioritizing high-importance fragments. Injected into prompts under `### ENHANCED MEMORY CONTEXT ###`.

### Proactive insights

`get_proactive_insights(user_id)` runs pattern detection:
- Trend detection (BP rising)
- Adherence patterns (missed doses)
- Symptom clusters
- Lifestyle correlations

Returns sorted insights with confidence + expiry. Top-2 injected into prompts.

### Importance scoring

Decision-rule heuristic, not learned:
- Emergency symptoms → 0.95+
- BP extremes → 0.9
- Medication changes → 0.85
- Normal BP → 0.6
- Greetings → 0.3

---

## 6.4 `firebase_context.py`

### Singleton (lines 29-65)
```python
class FirebaseContext:
    _instance = None
    _db = None
    
    def __new__(cls): ...
    def __init__(self):
        if not FIREBASE_AVAILABLE: return
        if path_exists: initialize_app(cred); self._db = firestore.client()
```

`is_available` checked by every caller before any operation.

### Read methods
- `get_user_profile`
- `get_bp_history(user_id, days=30)` ordered desc, limit 100
- `get_medications(user_id)` — only `isActive=True`; normalizes field shapes
- `get_user_medications` — alias
- `get_reminders`
- `get_latest_bp`

All wrap in `try/except` and return empty/None on failure. **Never raise.**

### Write methods
- `save_bp_reading`
- `add_medication` — has time-format adapter converting `{hour, minute}` to `"HH:MM"` for Flutter compatibility
- `add_reminder` — stores both `hour/minute` ints AND nested `time` for backward compat

### `build_user_context` (lines 343-433)

```python
profile, bp_history, medications = await asyncio.gather(
    get_user_profile(user_id),
    get_bp_history(user_id, days=30),
    get_medications(user_id),
)
```

Three features:

1. **`asyncio.gather`** — 3 reads in parallel, not serial.
2. **In-place trend detection** (lines 394-403): recent-3 vs older-3 with 5 mmHg threshold → "↑/↓/→".
3. **Missing Information section** (lines 421-431): if profile/age/meds empty, prompts LLM to ask the user.

### Sync-under-async caveat

Firebase Admin SDK is synchronous internally. Methods declared async but IO is sync. OK for FYP scale; production needs `asyncio.to_thread`.

---

## 6.5 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | Why two memory systems? | Layered: base=reliable, enhanced=best-effort. |
| 2 | Session eviction? | LRU+TTL via OrderedDict; move_to_end on access; popitem(last=False) for cap. |
| 3 | 2 workers running API? | State diverges. Need Redis. Single-worker assumption. |
| 4 | Importance scoring? | Hand-coded heuristic: emergency 0.95+, BP extremes 0.9, etc. |
| 5 | Brand normalization? | Flat sets ALL_MEDICATION_NAMES + BRAND_TO_GENERIC; word-boundary regex; brand→generic at storage. |
| 6 | Spoken number parsing? | `_words_to_number` walks tokens; ×100 for "hundred"; accumulator for tens+ones. |
| 7 | `_summarize_and_trim`? | Keeps last 10 verbatim + summary of last-5-of-dropped to prevent context loss. |
| 8 | Insight expiry? | `expires_at` timestamp; filtered on retrieval. |
| 9 | `asyncio.gather` benefit? | 3 reads parallel instead of serial → 3× to 1× latency. |
| 10 | Firebase missing? | `is_available=False`; callers fall through; system still works. |
| 11 | Trend algorithm? | Recent-3 vs older-3 with 5 mmHg threshold. Interpretable. |
| 12 | `add_medication` time format? | Converts dict to "HH:MM" string for Flutter compat. |
| 13 | Missing Information section? | Empty profile/age/meds → LLM prompts user to fill. |
| 14 | Memory corruption? | `try/except` everywhere; enhanced fails silently; base survives. |
| 15 | No persistence on memory? | Acknowledged; production fix = Firestore subcollection. |
| 16 | Multi-tenant leak risk? | Mitigated by hashing user_id into session_id. |

## 6.6 Honest weaknesses

1. No persistence; restart loses history.
2. Importance scores hand-coded.
3. Trend detection naïve (linear).
4. Firestore reads sync under async.
5. No row-level access control beyond app layer.
6. Brand list hard-coded.
7. Trim is lexical, not semantic.
