# Arteria — Flutter Frontend & Backend Integration: Complete Viva Guide

> Authoritative, code-verified walkthrough of the Flutter app and how it talks to the
> `QwenArteria/` backend. Written so you can answer a strict examiner on any layer.
> Read this together with the backend notes (`part_1`–`part_7`, `part_11`) and
> `QwenArteria/VIVA_PREPARATION.md`.

---

## 0. The 60-second mental model (say this first in your viva)

> "Arteria is a **voice-first blood-pressure companion**. The Flutter app is the client:
> it handles auth, lets the user log readings by **speaking naturally**, stores everything
> in **Firebase/Firestore**, and shows trends, insights, reminders and an on-device risk
> prediction. The **QwenArteria FastAPI server** is the brain for conversation: it runs a
> **three-tier hybrid LLM pipeline** where a cloud GPT model handles language and a local
> Qwen model does private analysis, while **all clinical classification is deterministic
> Python, never the LLM**. Firestore is the shared bus — both the app and the server read
> and write the same user data, which keeps the AI grounded in the user's real numbers."

That paragraph alone answers "explain your system." Everything below lets you defend it.

### One-picture architecture

```
┌──────────────────────────── FLUTTER APP (client) ────────────────────────────┐
│  Auth (Firebase) ─ Onboarding ─ Profile setup                                 │
│  Home ─ Voice logging ─ Insights chat ─ Trends ─ Reminders ─ Export ─ Settings│
│                                                                               │
│  State: BLoC/Cubit   |  Local ML: TFLite risk model   |  Secrets: envied      │
└───────┬───────────────────────────┬───────────────────────────┬──────────────┘
        │                           │                           │
        │ reads/writes              │ HTTPS REST                │ direct vendor calls
        ▼                           ▼                           ▼
┌───────────────┐        ┌────────────────────────┐   ┌────────────────────────┐
│  FIRESTORE    │◄──────►│  QwenArteria  FastAPI   │   │ OpenAI  (Whisper/TTS/  │
│ users/{uid}/  │ admin  │  zrok tunnel:           │   │   gpt-4.1-mini)        │
│  readings     │  SDK   │  arteriamain.share.zrok │   │ RunPod (WhisperV3)     │
│  medications  │        │  .io                    │   │ ElevenLabs (via server)│
│  reminders    │        │  /chat /analyze /speak …│   └────────────────────────┘
└───────────────┘        │  3-tier hybrid LLM      │
                         │  deterministic classify │
                         └────────────────────────┘
```

**The single most important thing to internalise:** the app does **not** route everything
through your backend. It uses your backend for *conversation/analysis*, but it also calls
some vendors *directly* and reads/writes Firestore *directly*. An examiner who finds this
will ask "why?" — the honest answer is **latency and bandwidth** (don't double-hop large
audio) plus **Firestore already being the source of truth**. See §6 and §10.

---

## 1. Technology stack and *why each choice*

| Concern | Choice | Defendable reason |
|---|---|---|
| UI framework | **Flutter** (Dart, SDK ^3.9.2) | Single codebase → Android + iOS; rich widget/animation system for a polished health UX |
| State management | **flutter_bloc** (BLoC + Cubit) | Predictable, testable, stream-based; event→state is easy to reason about and unit-test |
| Backend auth/data | **Firebase Auth + Cloud Firestore** | Managed auth (email + Google), real-time sync, offline persistence, and the *same* data the Python server can read via Admin SDK |
| HTTP | **http** + **dio** | `http` for simple calls; `dio` where interceptors/error-handling help |
| On-device ML | **tflite_flutter** | BP risk score computed locally → privacy, offline, <50 ms, no per-call cost |
| Audio record | **flutter_sound** / **record** | Capture mic to WAV (lossless) for transcription |
| Audio playback | **just_audio** / **audioplayers** | Play TTS replies |
| Charts | **fl_chart** | Native, animated BP trend lines |
| Calendar | **table_calendar** | Per-day reading view |
| Notifications | **flutter_local_notifications** + **timezone** | DST-safe scheduled medication reminders |
| PDF export | **pdf** + **printing** | Shareable clinical report for a doctor |
| Secrets | **envied** | Compile-time obfuscated API keys from `.env` |
| Localisation | **flutter_localizations** + ARB + `l10n.yaml` | English + French |
| Theming | **google_fonts**, Material 3, custom `ThemeCubit` | Light/dark with persisted preference |

**Trap question:** "Why both `http` and `dio`?" → Honest answer: historical/incremental;
`dio` adds interceptors and structured errors, `http` is fine for one-shot calls. If asked
to clean up, you'd standardise on one. Don't pretend it was a grand design.

---

## 2. App architecture: Clean Architecture + BLoC

### 2.1 Folder shape
Top level is **feature-based**; inside each feature it is **layered**:

```
lib/
├── main.dart                 # bootstrap + widget tree + routing
├── firebase_options.dart     # generated per-platform Firebase config
├── env/                      # envied: env.dart (annotations) + env.g.dart (generated)
├── l10n/                     # generated localisations (en, fr)
├── Core/Theme/               # app_theme.dart, theme_cubit.dart
├── services/                 # cross-cutting: health notifications, NL health service
└── features/
    ├── auth/        { domain (entities, repo interface), data (FirebaseAuthRepo), presentation (cubits, pages, components) }
    ├── home/        { data, domain, presentation/{components, bloc, pages/{Insights, BP_Predictor, settings}} }
    ├── microphone_transcribe/   # voice → BP logging pipeline (BLoC)
    ├── trends/      { data, domain (entities, usecases), presentation (bloc, widgets, pages) }
    ├── reminders/   # model, bloc, service (Firestore + local notifications)
    ├── export/      # PDF generation
    ├── FAQ/  splash/  user data/
```

**Why Clean Architecture?** Domain layer (entities + repository *interfaces*) has no Flutter
or Firebase imports, so business rules are testable and the data source is swappable
(e.g. `AuthRepo` interface ← `FirebaseAuthRepo` implementation; you could drop in a mock).

**Why BLoC?** UI dispatches **events**, the BLoC emits **states**, the UI rebuilds. It
separates *what happened* from *what to show*, and async work (network, Firestore) lives in
the BLoC, not the widget.

### 2.2 `main.dart` bootstrap — the order matters
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();          // platform channels ready first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuthRepo.initGoogleSignIn();           // pre-warm Google sign-in
  await ReminderService().initialize();                // notification channels + timezone
  await healthServices.initialize();                   // health notification service
  OpenAI.apiKey = Env.openaiApiKey;                    // configure dart_openai SDK
  runApp(const MyApp());
}
```
- `ensureInitialized()` **must** precede any `await` that uses platform channels (Firebase, notifications).
- `currentPlatform` picks the right Firebase config block at runtime.
- Non-critical steps are wrapped defensively so a notification-permission failure doesn't crash boot.

### 2.3 Widget tree & state composition
```
ChangeNotifierProvider<ThemeCubit>      // dark mode (lightweight, Provider)
 └ MultiBlocProvider [AuthCubits, UserBloc, SettingsBloc, ReminderBloc, TrendsBloc]
    └ MaterialApp (localised, themed, AnimatedTheme cross-fade, fade page routes)
       └ onGenerateRoute → '/' = _AuthWrapper, '/login', '/signup', '/profile-setup'
```
**Why mix Provider (ThemeCubit) and BLoC (everything else)?** Theme is a trivial toggle;
`ChangeNotifier` is lighter. It's an acceptable, *justifiable* inconsistency — admit it's not
ideal if pressed.

### 2.4 Three-state auth gate (`_AuthWrapper`)
`AuthCubits` emits: `AuthInitial → Unauthenticated | AuthenticatedNeedsProfileSetup | Authenticated | AuthError`.
- `Unauthenticated` → Onboarding/Login
- `AuthenticatedNeedsProfileSetup` → Profile setup (**can't be skipped** — this is why a
  distinct state exists; a logged-in user with no profile must finish setup before the app)
- `Authenticated` → Home
- `AuthError` → SnackBar via `BlocConsumer.listener`

**Trap:** "Why not just signed-in vs signed-out?" → Because Firebase Auth only stores
`uid`/`email`; the app needs extra profile fields (age, gender, conditions) in Firestore.
The middle state enforces collecting them.

---

## 3. The data model — Firestore is the shared bus

Everything hangs off `users/{uid}`:

| Subcollection / field | Written by | Read by |
|---|---|---|
| `users/{uid}/readings` (systolic, diastolic, pulse, `date: Timestamp`) | Voice-log BLoC, manual entry | App (home, trends, NL service), backend `firebase_context` |
| `users/{uid}/medications` | Medication tracker, backend MCP tool | App medication cards, NL service |
| `users/{uid}/reminders` | ReminderService, backend `set_reminder` tool | App reminder stream, scheduler |
| `users/{uid}` profile fields | Auth/profile setup | Risk model, AI context |

**Canonical rule (memorise):** all BP readings live in **`readings`** — never `bp_readings`.
The backend's `firebase_context.build_user_context()` reads this same path to ground the LLM,
which is *why* the AI can say "your last reading was 145/92" — it's not guessing, it's reading
your Firestore document.

**The key integration insight for the examiner:** the frontend and backend are *decoupled
through Firestore*. The app can write a reading and the backend will see it on the next
`/chat` call; the backend can set a reminder and the app's `snapshots()` stream shows it
instantly. Neither calls the other to sync — Firestore is the rendezvous point.

---

## 4. Feature-by-feature walkthrough (with integration points)

### 4.1 Authentication (`features/auth/`)
- `AuthRepo` interface + `FirebaseAuthRepo` implementation (Clean Arch boundary).
- Email/password via Firebase Auth; **Google Sign-In**: `authenticate()` → `idToken` +
  `accessToken` → `GoogleAuthProvider.credential` → `signInWithCredential`.
- New users → write profile to `users/{uid}` → state machine routes to Home.

### 4.2 Voice logging — **Pipeline A** (`microphone_transcribe/`)  ⟵ *most-tested feature*
This is "**tap mic, say your reading, it's logged and explained.**" It is **OpenAI-direct**,
*not* through your backend. ~12 events, explicit state machine.

**Flow:**
1. `StartRecording` → record WAV (`Codec.pcm16WAV`, lossless) to a temp file; `Timer.periodic` ticks a UI counter every second.
2. `StopRecording` → POST the WAV **directly** to `https://api.openai.com/v1/audio/transcriptions` (model **`whisper-1`**).
3. **Parse** the transcript with OpenAI chat (**`gpt-4.1-mini-2025-04-14`**) under a strict
   system prompt: *"Extract systolic and diastolic… never guess… respond ONLY with JSON
   `{"systolic":120,"diastolic":80}`"*. If none found → `{null,null}` and the app asks again.
   This is **LLM-as-a-structured-parser**, not LLM-as-a-doctor.
4. **Sanity check:** systolic must exceed diastolic, else they're assumed swapped/invalid.
5. **Session averaging (AHA guidance):** readings within a **10-minute window** of each other
   are averaged (AHA says take ≥2 readings 1–2 min apart and average). The *raw* reading is
   still stored so history is never lossy and re-aggregation can't double-count.
6. **Analyse + classify**, save the reading to `users/{uid}/readings`, and speak the reply
   via OpenAI TTS (**`tts-1`**, voice **`alloy`**) → played with `just_audio`.
7. Fire a `HealthNotification` if the reading is concerning.
8. `close()` cancels the timer, closes the recorder, disposes the player (no leaks).

**Why WAV not MP3?** Lossless; preserves fidelity for accurate transcription.
**Why call OpenAI directly (not via your server)?** Audio is large; a server hop doubles
bandwidth and adds latency. **Cost:** the OpenAI key ships in the app (obfuscated by envied,
*not encrypted*) — a real production app would proxy through the server. Say this openly.

### 4.3 Insights chat — **Pipeline B** (`home/.../Insights/`)  ⟵ *your LLM showcase*
This is "**have a conversation with Arteria.**" It goes **through your QwenArteria backend**.
Three service classes share one interface so the UI can switch implementations:
- `qwen_arteria_service.dart` — REST client to the backend; **RunPod WhisperV3 Turbo** for
  speech-to-text (async `run` + poll `status`), backend `/chat` for reasoning, backend
  `/speak` (**ElevenLabs**) for the voice reply.
- `hybrid_arteria_service.dart` — hits the Tier-1 hybrid endpoints.
- `novel_ai_service.dart` — uses `Env.qwenServerUrl`.

**Smart context injection (important detail):** before sending a chat message, the service
checks `_isAskingAboutBP(message)` (keywords like "my bp", "latest reading"). If true, it
pulls the latest reading from Firestore and **appends a formatted `[USER BP DATA]` block**
with a classification, so the LLM answers about *real* numbers. The transcription is shown
back to the user for verification before/with the response.

`processVoiceInteraction()` chains the full loop: **transcribe → chat → speak**.

The service exposes a typed **event stream** (`connected, transcribing, generating,
responseReceived, audioResponse, functionCall, error…`) so the UI (siri_wave waveform,
animated bubbles) reacts to each stage. `dispose()` closes the stream controller and HTTP
client.

> **You must be able to contrast Pipeline A vs B** — see §6. This is the question that
> separates a pass from a strong pass.

### 4.4 Natural-language health service (`services/natural_language_health_service.dart`)
A **hybrid local approach**: it sends the query to the backend `/chat` *only to classify
intent* into one of 8 types (HEALTH_STATUS, RISK_SCORE, BP_READINGS, ANOMALIES, TRENDS,
MEDICATION, RECOMMENDATIONS, COMPARISON). Then it **builds the actual answer in Dart** from
Firestore + the local risk-score service, fully bilingual (en/fr). If the LLM call fails it
falls back to keyword intent detection. **Why?** Deterministic, grounded, cheap answers for
"how's my health?" without trusting the LLM with the numbers. Note: anomaly detection here is
a simple delta rule (Δsystolic > 20 or Δdiastolic > 15 between consecutive readings).

### 4.5 BP risk predictor (on-device TFLite) (`home/.../BP_Predictor`, data sources)
- Loads a `.tflite` model + `model_metadata.json` (feature order, means, stds).
- Builds the feature vector in metadata order → **z-score normalises** `(x−μ)/σ` → runs the
  interpreter → clamps output to `[0,1]`.
- Categorical encoding (gender 0/0.5/1, booleans 0/1) **must match the training pipeline**.
- **Fallback:** if TFLite fails to load (e.g. iOS asset quirk → copy to temp first), a
  rule-based heuristic (age, BP, smoker, diabetes) returns a score. **The app never crashes.**
- **Why on-device?** Privacy (health data stays local), latency, offline, zero per-inference cost.

### 4.6 Trends (`features/trends/`)
- `trends_analytics.dart` is **pure Dart**: moving average, outlier detection (IQR/z-score),
  linear-fit trend slope, day-of-week patterns.
- `fl_chart` line chart + `table_calendar` + summary stats; `TrendsBloc` (Load/Refresh →
  Loading/Loaded/Error). Clean Architecture with explicit *usecases*
  (`get_trends_data_usecase`, `export_trends_usecase`).

### 4.7 Reminders (`features/reminders/`)
- `ReminderService` **singleton** (factory) = single source of truth, prevents duplicate
  scheduling.
- Init: timezone data (DST-safe), Android 13+ runtime `POST_NOTIFICATIONS`, iOS alert/badge/sound.
- `watchReminders` returns `_remindersCollection(userId).snapshots().map(...)` → a **live
  Firestore stream**; UI updates via `StreamBuilder`.
- Scheduling uses `tz.TZDateTime`; repeat types daily/weekdays/weekly/custom.
- **Cross-feature integration:** the backend's MCP `set_reminder` tool writes to the same
  Firestore collection → the app's stream picks it up with no polling. Demo this; it's
  impressive and it proves the Firestore-as-bus design.

### 4.8 Export (`features/export/`)
PDF via `pdf` + `printing`: header → summary → embedded chart → readings table →
**medical disclaimer footer** (regulatory hygiene — you are not a medical device).

### 4.9 Settings / Theme / Localisation
`ThemeCubit` persists dark mode via `shared_preferences`; `SettingsBloc` holds locale + units;
`AnimatedTheme` gives a 250 ms cross-fade. Adding a language = add `app_xx.arb` → codegen →
append `Locale('xx')`.

---

## 5. Backend integration contract (what the app actually calls)

**Base URL:** `Env.qwenServerUrl` → `https://arteriamain.share.zrok.io` (a **zrok** tunnel
that exposes the locally-run FastAPI server to the phone over HTTPS). Default fallback
`http://localhost:8000`.

### Endpoints the app uses
| Endpoint | Method | App caller | Purpose |
|---|---|---|---|
| `/health` | GET | service `connect()` | check server + Firebase status before use |
| `/chat` | POST | Insights services, NL health service | main conversation (3-tier) |
| `/analyze` | POST | `analyzeBP()` | structured BP reading analysis |
| `/speak` | POST | `speak()` | server-side ElevenLabs TTS → audio bytes |
| `/session/clear` | POST | `clearSession()` | wipe conversation memory for a session |

Other server endpoints exist (`/chat/stream`, `/hybrid/analyze`, `/hybrid/audio`,
`/transcribe`, `/chat/voice-aware`, `/medication/interactions`,
`/voice/stress-correlation/{user_id}`, OpenAI-compatible `/v1/chat/completions`) — know they
exist; the primary client path is the five above.

### `/chat` request / response shape
```jsonc
// request
{ "message": "...", "user_id": "<uid>", "session_id": "<id|null>", "language": "en|fr" }
// response
{ "response": "...", "session_id": "...", "function_calls": [...], "inference_time_ms": 1234 }
```
The app **stores the returned `session_id`** and sends it next time → that's how multi-turn
memory works. `function_calls` surfaces tool actions (e.g. a reminder was set) to the UI.

### What happens server-side on `/chat` (3-tier graceful degradation)
1. **Tier 1 — Hybrid** (needs internet + `OPENAI_API_KEY`): build user context from Firebase
   + conversation history → `process_hybrid_request`. **GPT understands intent & polishes
   wording; local Qwen3-8B does the analysis.** Save to memory. Return.
2. **Tier 2 — LangGraph agents** (local Qwen only) if hybrid fails/disabled.
3. **Tier 3 — Direct Ollama** fallback — basic but always works offline.
**The app code is identical for all three** — it just sends `/chat` and reads `response`. The
tiering is invisible to the client; that's the point of putting it behind one endpoint.

### `/analyze` returns a *deterministic* classification
`classify_bp(systolic, diastolic, …)` (pure Python) decides the category and the
`is_emergency` flag; the LLM only writes the surrounding prose. The response carries
`classification`, `is_emergency`, `response`, `recommendations`, `session_id`.

---

## 6. The two voice pipelines — the question that decides your grade

| | **Pipeline A: Voice logging** | **Pipeline B: Insights chat** |
|---|---|---|
| Goal | Log a reading hands-free | Converse with the assistant |
| File | `microphone_transcribe_bloc.dart` | `qwen_arteria_service.dart` / `hybrid_arteria_service.dart` |
| Speech-to-text | **OpenAI Whisper** (`whisper-1`), **direct from app** | **RunPod WhisperV3 Turbo**, direct from app |
| Reasoning | **OpenAI `gpt-4.1-mini`**, direct (JSON parse) | **Your backend `/chat`** (3-tier hybrid) |
| Text-to-speech | **OpenAI TTS** (`tts-1`, alloy), direct | **Backend `/speak`** → ElevenLabs |
| Clinical decision | Deterministic Dart classifier | Deterministic Python `classify_bp` |
| Persistence | Writes `readings` | Reads `readings` for context |

**Why two?** Logging needs *fast, structured extraction* of two numbers — a tiny direct LLM
call is simplest and lowest-latency. The Insights chat is where your **research contribution**
lives (the hybrid local+cloud pipeline, privacy-preserving analysis, memory). Keeping them
separate means a transcription outage in one doesn't break the other.

**If the examiner says "that's inconsistent / why not one path?"** — agree it could be
unified by routing Pipeline A's transcription through `/transcribe` and parsing server-side;
you split them for **latency and development speed**, and it's a fair future refactor. Owning
the trade-off scores higher than defending it as perfect.

---

## 7. The safety architecture — your strongest talking point

> **"GPT owns the words, Python owns the numbers and clinical categories."**

- BP **classification is deterministic** (`classify_bp()` server-side; mirrored Dart logic
  client-side). The LLM is **never** asked "is this hypertension?" — it's told the answer and
  asked to explain it kindly.
- In the hybrid orchestrator, **BP digits are masked to placeholder tokens** before the
  polish LLM sees them, so the model *cannot* alter a reading (no "145" silently becoming
  "154").
- The voice-logging parser is constrained to **emit JSON or null** and is forbidden to guess.
- Every reading is **stored raw**; averages are derived, never destructive.
- PDF export and the app carry a **medical disclaimer**.

This is the answer to "isn't it dangerous to let an LLM give medical advice?" → **The LLM
does not make clinical decisions; deterministic code does, and the LLM only communicates them.**

> **Deliberate, not a bug:** 120/80 classifies as **"Normal"**, not "Elevated". This is an
> intentional, documented choice (not strict 2017-AHA, which calls 120/80 elevated). If an
> examiner "corrects" you, explain it's a deliberate threshold decision, consistent across
> the app — don't let them rattle you into calling it a defect.

---

## 8. Security & secrets (be honest — examiners reward candour)

- **Keys via `envied`:** `OPENAI_API_KEY`, `RUNPOD_API_KEY`, `QWEN_SERVER_URL` are read from
  `.env` (gitignored) and compiled into `env.g.dart` as **XOR-obfuscated** constants.
- **Obfuscation ≠ encryption.** A determined attacker can extract them from the binary.
  **The correct production fix is a server-side proxy** so keys never ship to the client.
  Say this *before* they catch it.
- Firestore must be protected by **Security Rules** (`users/{uid}` readable/writable only by
  that authenticated uid) — if you haven't locked them down, acknowledge it as a to-do.
- The **zrok tunnel** is a dev convenience for exposing localhost; production would be a
  hardened HTTPS host with auth on the API.

---

## 9. Honest weaknesses (have these ready — volunteering them disarms a strict examiner)

1. API keys are obfuscated, not encrypted — should be behind a server proxy.
2. Two voice pipelines / two HTTP libs (`http` + `dio`) — could be unified.
3. `'default_user'` placeholder during bootstrap before auth resolves is hacky.
4. No global error boundary; routes are hard-coded (production → `go_router`).
5. No retry/back-off on network calls; `fl_chart` can get janky with hundreds of points.
6. Client-side anomaly detection is a simple threshold rule, not statistical.
7. Mixed Provider + BLoC for state.
8. Limited accessibility labels; exported PDFs are unsigned.

For each, you can state the fix — that's what "in-depth clarity" looks like to an examiner.

---

## 10. Strict-examiner Q&A bank

**Architecture & Flutter**
- *Why Flutter?* One codebase, native performance, strong animation/widget system for a
  consumer health app.
- *Why BLoC over Provider/Riverpod?* Predictable event→state, testable, stream-friendly;
  Provider used only for the trivial theme toggle.
- *What is a Cubit vs a BLoC?* Cubit = function calls emit states (no events); BLoC = events
  map to states. Cubit for simple, BLoC for richer flows.
- *Why Clean Architecture?* Swappable data sources behind domain interfaces; testable rules.
- *Why three auth states?* Firebase stores only uid/email; the middle state forces profile
  completion before Home.
- *Where is dark mode persisted?* `shared_preferences` inside `ThemeCubit`.

**Backend integration**
- *How does the app talk to the backend?* HTTPS REST to the zrok-tunnelled FastAPI server;
  `/chat`, `/analyze`, `/speak`, `/health`, `/session/clear`.
- *How is multi-turn memory kept?* Server returns `session_id`; app resends it; server keys
  conversation history by `user_id`+`session_id`.
- *How does the AI know my readings?* The app injects a `[USER BP DATA]` block from Firestore
  when the query is BP-related, AND the server independently reads `users/{uid}/readings` via
  the Firebase Admin SDK in `build_user_context()`.
- *What are the three tiers and why?* Hybrid (GPT+Qwen) → LangGraph (local) → Ollama
  (fallback): graceful degradation so the assistant still works offline or if OpenAI is down.
- *Is the LLM making the diagnosis?* No — `classify_bp()` is deterministic Python; the LLM
  only explains. BP digits are even masked from the polishing model.

**Voice / the two pipelines**
- *Walk me through logging a reading by voice.* (Recite Pipeline A, §4.2.)
- *Why does logging use OpenAI but chat uses your server?* Latency/bandwidth for the simple
  extraction vs. showcasing the hybrid research pipeline for conversation. (§6.)
- *Why WAV?* Lossless → better transcription.
- *Why RunPod for the chat transcription?* On-demand GPU Whisper-V3 with async run+poll;
  decouples heavy STT from the app.
- *What if Whisper mis-hears "140" as "114"?* The parser asks for JSON only and won't guess;
  the systolic>diastolic sanity check and the user-visible transcription catch errors; the
  user can re-record.

**ML / data**
- *Why on-device TFLite?* Privacy, latency, offline, cost.
- *Why z-score normalise?* The model was trained on standardised features; inference must
  match. Means/stds come from `model_metadata.json`.
- *What if the model file is missing?* Rule-based fallback; the app never crashes.
- *Where do readings live?* `users/{uid}/readings` — single canonical collection.

**Security**
- *Where are API keys?* `envied` compile-time obfuscated — obfuscation, not encryption;
  production should proxy through the server. *(Volunteer this.)*
- *How is Firestore secured?* Should be locked by Security Rules to the owning uid.

**Curveballs**
- *Your app gives medical advice — liability?* It classifies deterministically, always
  recommends consulting a professional, shows a disclaimer, and is positioned as a
  *monitoring companion*, not a diagnostic device.
- *Offline behaviour?* Firestore offline persistence queues writes; TFLite + Tier-3 Ollama
  keep core function; cloud chat degrades gracefully.
- *How would you scale to 100k users?* Replace zrok with a managed HTTPS backend +
  autoscaling, move keys server-side, batch/queue inference, add caching and rate limiting.
- *Why 120/80 = Normal?* Deliberate threshold choice, consistent across app (§7).

---

## 11. Predictive Timeline: reliability & calibration

The Trends "future forecast" (`lib/features/trends/presentation/widgets/predictive_timeline.dart`)
is the one place an examiner will push hardest — *"prove it's accurate."* Don't over-claim.

**The reframe (say this first):** It is **not** a clinical predictor of future blood pressure.
It is a **transparent trend-extrapolation with an explicit uncertainty band** — an
early-warning/motivational indicator. It fits **ordinary-least-squares linear regression** on
the **EWMA-smoothed Daily Risk Score** (stable slope, robust to single-day spikes) and projects
7 days forward with a 95% prediction interval. It needs ≥7 observations or it stays "locked".

**How it's validated:** a walk-forward (rolling-origin) backtest in `tool/forecast_backtest.dart`
reuses the exact forecast math on 500 reproducible synthetic series. Run with
`dart run tool/forecast_backtest.dart`. Headline numbers: 1-day-ahead error **MAE ≈ 2.7 risk
points / 100**, rising to ≈6.7 at 7 days (so it widens the band honestly the further out it goes).

**Calibration story — coverage of the 95% band against the *real future day*:**

| Band sizing | Overall coverage | Note |
|--|--|--|
| EWMA residuals + Normal z=1.96 (original) | ~45% | badly over-confident |
| EWMA residuals + Student-t (t-fix) | ~51% | t widens it for small n (df=5 ⇒ t≈2.57) |
| **RAW daily residuals + Student-t (current)** | **~97%** | right at the 95% target |

The fix: keep the slope on the EWMA, but size the interval from the **raw** daily residuals.
EWMA residuals are autocorrelated and artificially tiny, which made the band over-confident.

**Three gotchas to pre-empt (volunteer these before the examiner finds them):**
1. **MAE is identical across all three band variants** — the point forecast never changed; only
   the *interval width* did. The fixes are about *calibrated uncertainty*, not accuracy.
2. **~97% is slightly conservative** (band marginally wide) — that's the *safe* direction for a
   health app. Don't claim it's perfectly 95%.
3. **It forecasts a constructed proxy (the DRS index), not clinical BP directly** — and the DRS's
   lifestyle term is still a constant-50 placeholder. So it's "trend of a risk score," not "your
   systolic next Tuesday."

One-line defence: *"I measured it rather than guessed — the band now empirically covers ~97% of
real future days, and I can name exactly why the earlier version under-covered."*

---

## 12. How to run the demo (so nothing surprises you live)

1. Start the backend: `QwenArteria/start_production.sh` (brings up FastAPI + the zrok tunnel
   at `arteriamain.share.zrok.io`). Confirm `GET /health` returns `firebase_connected: true`.
2. Launch the app (`flutter run`); sign in; ensure a couple of readings exist in Firestore.
3. **Demo Pipeline A:** tap the mic, say *"My blood pressure is 138 over 88"* → watch it
   transcribe, parse, classify, save, and speak back.
4. **Demo Pipeline B:** open Insights, ask *"How has my blood pressure been this week?"* →
   show it pulling real Firestore data and the spoken reply.
5. **Demo the bus:** have the assistant set a reminder → show it appear instantly in the
   Reminders screen (proves Firestore-as-bus).
6. Show Trends chart, the on-device risk score, and PDF export with the disclaimer.

**If the network/tunnel dies mid-demo:** stay calm and narrate the graceful degradation —
"this is exactly the Tier-3 offline fallback I designed for." That turns a failure into a
talking point.

---

### Final exam-day mantra
> Client = Flutter (BLoC, Firestore, on-device ML, two voice paths).
> Server = QwenArteria (3-tier hybrid LLM, deterministic clinical core).
> Bus = Firestore.
> Safety = **GPT owns the words, Python owns the numbers.**
