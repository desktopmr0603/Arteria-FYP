# PART 9 — Flutter Critical Features

## 9.1 Authentication (`features/auth/`)

### Architecture
```
auth/
├── domain/{entities/app_user, repo/auth_repo}/
├── data/firebase_auth_repo.dart
└── presentation/{components, cubits, pages}/
```

`AuthRepo` interface + `FirebaseAuthRepo` implementation. Lets you swap providers/mocks.

### `FirebaseAuthRepo` key methods
- `initGoogleSignIn()` — static, idempotent. Uses Android client ID + server client ID for Firebase token verification.
- `loginWithEmailPassword`, `registerWithEmailPassword` — standard Firebase Auth.
- `signInWithGoogle()` — authenticate → idToken + accessToken → GoogleAuthProvider.credential → Firebase signInWithCredential.
- `addUserDetails` — writes to Firestore users/{uid}.
- `logout` / `deleteAccount`.

### `AuthCubits` state machine
States: AuthInitial, Unauthenticated, AuthenticatedNeedsProfileSetup, Authenticated, AuthError.
`_AuthWrapper` in main.dart routes based on state.

---

## 9.2 Microphone Transcribe (`features/microphone_transcribe/`)

### BLoC structure
~12 events (StartRecording, StopRecording, RecordingTick, TranscriptionCompleted/Failed, LLMAnalysisStarted/Completed/Failed, TTSPlaybackStarted/Completed/Failed, AutoSaveTriggered, ResetState).

States: Initial, Recording(secondsElapsed), ProcessingTranscription, TranscriptionComplete, ProcessingLLMAnalysis, AnalysisComplete, PlayingTTS, PlaybackComplete, Error.

### Pipeline
1. **StartRecording**: temp WAV path with `Codec.pcm16WAV` (lossless, broad compat).
2. **Timer.periodic** ticks every second to update UI counter.
3. **StopRecording** → `_transcribeAudio` direct to OpenAI Whisper API.
4. LLM analysis via backend `/chat`.
5. TTS playback via backend `/speak` → `just_audio`.
6. AutoSave to Firestore.

### Why direct OpenAI from client?
Audio files are large; round-trip through backend doubles bandwidth.

**Trade-off:** API key in client binary (envied) — extractable. Production: server proxy.

### Resource cleanup
`close()` cancels timer, closes recorder, disposes audio player.

---

## 9.3 BP Predictor (TFLite, on-device)

### Why TFLite
Privacy + latency (<50ms) + offline + cost.

### Model loading
- iOS: copy asset to temp file then load (workaround for direct-asset load issues).
- Android: direct asset load.
- Reads `model_metadata.json` for feature names + means + stds.

### Inference (`predictRisk`)
1. Build feature vector in metadata-specified order.
2. Z-score normalize: `(x - μ) / σ`.
3. Reshape to `[1, N]`.
4. Run interpreter.
5. Clamp output to `[0, 1]`.

### Fallback (`getFallbackRisk`)
Rule-based scoring (age, BP, smoker, diabetes). Used when TFLite fails. App never crashes.

### Categorical encoding
`_parseFeatureValue`: gender (female=1, male=0, other=0.5); booleans → 0/1. **Must match training pipeline.**

---

## 9.4 Reminders

### Architecture
```
reminders/
├── reminder_model.dart        # Reminder + RepeatType
├── reminder_event/state.dart
├── reminder_bloc.dart
├── reminder_service.dart      # Firestore + flutter_local_notifications
└── ui/reminder_settings_screen.dart
```

### `ReminderService` singleton (factory pattern)

### Initialization
- Initialize timezone data (cross-DST scheduling).
- Android: launcher icon as notification icon.
- iOS: request alert/badge/sound permissions.
- Android 13+: runtime POST_NOTIFICATIONS permission.

### Real-time stream (`watchReminders`)
```dart
return _remindersCollection(userId).snapshots().map(...);
```
Firestore live updates → UI auto-refreshes via StreamBuilder.

### Adding a reminder
1. Build Reminder model.
2. Write to Firestore.
3. Schedule local notification with `tz.TZDateTime`.
4. Repeat types: daily, weekdays, weekly, custom.

### Cross-feature integration
Backend MCP `set_reminder` writes to Firestore; Flutter snapshots stream picks it up instantly. **Backend-frontend sync via Firestore.**

---

## 9.5 Insights / Hybrid Service

### Files
- `hybrid_arteria_service.dart` — calls Tier 1 backend (`/chat`, `/hybrid/audio`).
- `qwen_arteria_service.dart` — Tier 2 legacy backend.
- `insights_screen.dart` — toggle in AppBar.

### Toggle exposed for demo
Lets you show GPT+Qwen vs Qwen-only response style differences.

### Service signature
```dart
Future<String> sendMessage(String message, String userId) async {
  final response = await dio.post('$backendUrl/chat', data: {...});
  return response.data['response'];
}
```

Uses Dio (interceptors, error handling).

### Voice variant
Base64 audio → `/hybrid/audio` → `{transcription, response, ...}`. Transcription shown back to user for verification.

### UI
`siri_wave` for waveform animation; `flutter_animate` for message bubbles.

---

## 9.6 Trends

### Purpose
Line chart (fl_chart) + calendar (table_calendar) + summary stats.

### `trends_analytics.dart`
Pure Dart: moving average, outlier detection (IQR/z-score), linear-fit trend, day-of-week patterns.

### BLoC
events: LoadTrends(period), RefreshTrends. states: Loading, Loaded, Error.

---

## 9.7 Notifications

Surface push (HealthNotificationService) + reminder-fires (local) + backend insights (polled). HealthNotificationCard with severity color + action button.

---

## 9.8 Export

`export_service.dart` generates PDFs via `pdf` + `printing`. Layout: header → summary → embedded chart → readings table → disclaimer footer. **Disclaimer regulatory hygiene.**

---

## 9.9 FAQ + Splash

FAQ: static expandable list, localized.
Splash: Rive animation while app boots.

---

## 9.10 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | Why Clean Architecture for auth? | Swap auth provider via interface; testable. |
| 2 | Google Sign-In flow? | init→authenticate→idToken+accessToken→Firebase credential. |
| 3 | Profile fields in Firestore? | Auth only stores uid/email; custom fields need Firestore. |
| 4 | Direct OpenAI for transcription? | Avoid double bandwidth on audio. |
| 5 | Trade-off of direct OpenAI? | API key extractable. Production: proxy. |
| 6 | Why TFLite on-device? | Privacy + latency + offline + cost. |
| 7 | TFLite fails to load? | Fallback rule-based heuristic. |
| 8 | Categorical encoding? | gender 0/0.5/1; booleans 0/1; must match training (metadata.json). |
| 9 | Why z-score normalization? | Trained model expects normalized features. |
| 10 | Reminder sync backend↔frontend? | Firestore snapshots() stream. |
| 11 | Singleton ReminderService? | Single source of truth; prevents duplicate scheduling. |
| 12 | Notifications timezone-aware? | tz.TZDateTime + initialized timezone data; DST-safe. |
| 13 | Why Dio over http? | Interceptors, error handling, cancellation. |
| 14 | Hybrid/Legacy toggle? | Two services with same interface; UI selects. |
| 15 | fl_chart purpose? | Native interactive charts, smooth animations. |
| 16 | flutter_animate role? | Declarative animations via fluent API. |
| 17 | iOS recording failure? | ErrorState with message; UI shows + resets. |
| 18 | Why WAV not MP3? | Lossless; preserves stress signals for voice analysis. |
| 19 | Conversation history? | Backend keyed by user_id+session_id; Flutter passes session_id. |
| 20 | Firestore offline? | SDK has offline persistence; queues writes. |

## 9.11 Honest weaknesses

1. OpenAI key in client.
2. Microphone resource leaks if BLoC not disposed.
3. TFLite encoding brittle.
4. Reminder notifications can drift if device sleeps.
5. No retry logic on Dio calls.
6. fl_chart janky with hundreds of points.
7. Export PDFs unsigned.
8. Limited accessibility labels.
