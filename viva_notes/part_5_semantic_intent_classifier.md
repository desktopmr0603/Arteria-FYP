# PART 5 — `semantic_intent_classifier.py` DEEP DIVE

## 5.1 Purpose

The **brain that turns natural language into an `Intent` enum + entities** for the LangGraph router (Tier 2 path). Independent from the GPT-4o-mini classifier in `hybrid_orchestrator.py`; runs entirely locally.

## 5.2 The three-strategy ensemble

```
classify_intent(text, conversation_history, user_context):
    Strategy 1: LLM Classification (Qwen via Ollama)        weight=0.5
    Strategy 2: TF-IDF Semantic Similarity                  weight=0.3
    Strategy 3: Rule-based keyword fallback                 weight=0.2
    
    final_intent = argmax(weighted_scores)
    Apply post-classification guards
    Return IntentResult(intent, confidence, reasoning, entities)
```

Standard ensemble pattern: combine multiple classifiers with weights to outperform any single method.

**Why this ensemble?**
- LLM: best at nuance, slow, occasionally wrong.
- TF-IDF: fast, deterministic, only catches close paraphrases.
- Rules: catches patterns the others miss.

## 5.3 The `Intent` enum (lines 46-60)

13 values; router collapses CONVERSATION/RECOMMENDATIONS to GENERAL. CLARIFICATION and PROACTIVE_INSIGHT are legacy from earlier design.

## 5.4 `intent_examples` (lines 80-277)

Hand-curated bilingual (EN/FR) example bank, ~150 examples keyed by intent. Used by both TF-IDF and LLM few-shot.

**Why bilingual?** TF-IDF doesn't understand French; without examples, French queries fail.

## 5.5 TF-IDF setup (lines 280-300)

```python
TfidfVectorizer(
    ngram_range=(1, 3),    # uni/bi/trigrams
    stop_words=None,       # multilingual safe
    lowercase=True,
    max_features=1500,
)
```

Fit once at init; inference is microseconds per query.

## 5.6 `_extract_entities` (line 392)

Regex-pulls structured entities (BP reading, medications, dosage, time, timeframe, numbers) **independently of intent**.

## 5.7 Strategy 1: `_llm_intent_classification` (line 452)

Calls Qwen via Ollama with structured prompt requesting JSON `{intent, confidence, reasoning}`. Falls back to GENERAL/0.3 if malformed.

**Performance note:** Tier 2 hits Qwen twice (classify + respond) — about 1-2s extra latency.

## 5.8 Strategy 2: `_semantic_similarity_match` (line 545)

```python
text_vec = self.vectorizer.transform([text])
similarities = cosine_similarity(text_vec, self.intent_vectors).flatten()
best_idx = np.argmax(similarities)
return self.intent_labels[best_idx], similarities[best_idx]
```

O(N×D) ~225K multiplications. Microseconds.

## 5.9 Strategy 3: `_rule_based_fallback` (line 585)

If-elif chain over keyword patterns. Conservative confidences (rarely >0.8). Safety net for cases the other two miss.

## 5.10 `_apply_post_classification_guards` (line 847)

**Post-hoc rule rewrites** for known failure modes:
- BP_ANALYSIS guard: if no BP entity, demote to GENERAL.
- EMERGENCY guard: if no emergency signal, demote.
- LIFESTYLE vs HISTORY: disambiguate "my coffee intake affecting MY BP".
- MEDICATION vs OOS: "buy me amlodipine" → OOS.

Encodes lessons from manual review of failed cases.

## 5.11 Pre-classification fast paths (lines 305-386)

Three early-return checks that bypass the ensemble:
- `_unsupported_external_health_data_sharing` → OOS at 0.93.
- `_is_educational_mechanism_question` → LIFESTYLE.
- `_explicit_stored_data_review` → HISTORY.

## 5.12 `classify_intent` (line 1118)

Pipeline:
1. extract entities
2. external-data-sharing check (early return)
3. build context
4. run all 3 strategies
5. weighted vote
6. apply post-guards
7. return IntentResult

If anything throws → IntentResult(GENERAL, 0.3). Fail-soft.

## 5.13 Held-out test suite

`test_held_out_paraphrases.py` + 23 KB JSON of test cases with `gold_intent` labels. Tests paraphrases, edge cases, adversarial inputs. **Real evaluation methodology** — not just vibes.

## 5.14 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | Why three strategies? | Ensemble diversity → robustness. |
| 2 | The weights? | 0.5/0.3/0.2 — LLM dominates, others can override. Empirically tuned. |
| 3 | Why TF-IDF over sentence transformers? | Microseconds no GPU; ~150 examples needs only TF-IDF. |
| 4 | Why ngram_range=(1,3)? | Captures multi-word concepts. |
| 5 | Why stop_words=None? | Multilingual safety. |
| 6 | LLM returns bad JSON? | Falls back to GENERAL/0.3; ensemble survives. |
| 7 | Walk through "buy me amlodipine". | Entities=medications. LLM/rules/semantic likely vote MEDICATION. Post-guard catches "buy" → OUT_OF_SCOPE. |
| 8 | Post-classification guards? | Rules correcting ensemble output for known failure modes. |
| 9 | Accuracy measurement? | Held-out paraphrase set with gold intents; top-1 + per-intent metrics. |
| 10 | Cold-start time? | TF-IDF fit ~50ms once; inference dominated by Qwen ~1-3s. |
| 11 | Why entities separate from intent? | Entities = facts; intent = interpretation. Decoupling lets entities inform without constraining. |
| 12 | French user types English? | Both languages handled; system prompt enforces response language downstream. |
| 13 | Could you replace with GPT-4o-mini alone? | Yes — Tier 1 does that. This module is the offline Tier 2. |
| 14 | Vague queries? | LLM low confidence; ensemble settles on GENERAL; clarifying response. |
| 15 | Worst-case latency? | LLM 10s timeout → fallback to semantic+rule consensus. ≤12s end-to-end. |

## 5.15 Honest weaknesses

1. Hand-curated examples — biased toward common phrasings.
2. Hard-coded weights — should be learned.
3. TF-IDF doesn't handle synonyms.
4. Post-guards are ad-hoc tech debt.
5. No active learning loop.
6. Confidences not calibrated across strategies.
