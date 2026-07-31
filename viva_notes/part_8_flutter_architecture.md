# PART 8 — Flutter App Architecture

## 8.1 Top-level overview

Clean Architecture (data/domain/presentation) with **BLoC + Cubit** for state management.

**Stack:** Flutter ^3.9.2, flutter_bloc, firebase_core/auth/firestore, dio + http, record/flutter_sound, just_audio/audioplayers, tflite_flutter, flutter_local_notifications, fl_chart/table_calendar, pdf/printing, flutter_secure_storage, provider, envied.

## 8.2 Folder structure

```
lib/
├── main.dart
├── firebase_options.dart
├── env/ (env.dart, env.g.dart)
├── l10n/
├── Core/Theme/ (app_theme, theme_cubit)
├── Core/Utils/
├── services/
└── features/
    ├── auth/{data, domain, presentation}/
    ├── home/{data, domain, presentation/pages/{homepage, Insights, BP_Predictor, settings}}/
    ├── microphone_transcribe/
    ├── reminders/
    ├── notifications/
    ├── trends/
    ├── export/
    ├── FAQ/
    ├── splash/
    └── user data/
```

**Feature-based at top level**, layered (data/domain/presentation) inside each feature.

## 8.3 `main.dart` (213 lines)

### Async main (lines 33-81)
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuthRepo.initGoogleSignIn();
  await ReminderService().initialize();
  await healthServices.initialize();
  OpenAI.apiKey = Env.openaiApiKey;
  runApp(const MyApp());
}
```

**Key lines:**
- `WidgetsFlutterBinding.ensureInitialized()`: required before await in main.
- `DefaultFirebaseOptions.currentPlatform`: per-platform config.
- Non-critical wrapped in try/except — defensive bootstrap.
- `Env.openaiApiKey`: compile-time obfuscated via envied.

### Widget tree (lines 84-178)

```
ChangeNotifierProvider<ThemeCubit>
  Consumer<ThemeCubit>
    MultiBlocProvider [AuthCubits, UserBloc, SettingsBloc, ReminderBloc, TrendsBloc]
      BlocBuilder<SettingsBloc>
        AnimatedTheme
          MaterialApp (localized, themed, fade-routed)
            onGenerateRoute → '/'→AuthWrapper, '/login', '/signup', '/profile-setup'
```

### Mixed Provider + BLoC
ThemeCubit uses Provider's ChangeNotifierProvider; everything else uses BlocProvider. Acceptable trade-off; ChangeNotifier lighter for simple toggle.

### The 5 BLoCs
| BLoC | Responsibility |
|---|---|
| AuthCubits | Auth state (Unauth, Auth, NeedsProfileSetup) |
| UserBloc | Profile data |
| SettingsBloc | Locale, units, theme persistence |
| ReminderBloc | Medication reminders CRUD |
| TrendsBloc | BP trends/analytics |

Cascade operator `..checkAuth()` initiates async load on creation.

### Localization
```dart
localizationsDelegates: [AppLocalizations.delegate, GlobalMaterial..., GlobalWidgets..., GlobalCupertino...],
supportedLocales: [Locale('en'), Locale('fr')],
locale: settingsState.locale,
```

`l10n.yaml` drives Flutter codegen from `.arb` files.

### `AnimatedTheme`
Smooth 250ms cross-fade for dark mode toggle.

### `onGenerateRoute`
PageRouteBuilder with FadeTransition for uniform 300ms fade across routes.

### `_AuthWrapper` (lines 185-211)
BlocConsumer pattern:
- builder: routes by AuthStates (Unauth→Onboarding, Auth→Homepage, NeedsProfile→Setup, default→Loading)
- listener: AuthError → SnackBar

**Three-state auth** prevents users skipping profile setup.

## 8.4 Theme system

`app_theme.dart` — lightTheme + darkTheme ThemeData. Material 3, google_fonts.
`theme_cubit.dart` — ChangeNotifier with isDarkMode + toggleTheme; persists via shared_preferences.

## 8.5 `envied` for env vars

Workflow:
1. `.env` has API keys (gitignored).
2. `lib/env/env.dart` has @Envied() class with @EnviedField() annotations.
3. `dart run build_runner build` generates `env.g.dart` with XOR-obfuscated constants.

**Compile-time, not runtime.** More secure than flutter_dotenv but **not cryptographic** — extractable by determined attacker. Truly secure needs server-side proxy.

## 8.6 Service init order (matters)

1. WidgetsFlutterBinding
2. Firebase.initializeApp
3. FirebaseAuthRepo.initGoogleSignIn (pre-warm)
4. ReminderService.initialize (notification channels)
5. Health services with `'default_user'` placeholder (rebuilt post-auth)
6. OpenAI.apiKey
7. runApp

Defensive try/except prevents bootstrap crash.

## 8.7 BLoC primer

```
UI ─Event→ BLoC ─State→ UI
              │
              ▼
        Repo / data
```

Why BLoC: predictable, testable, async-friendly.

## 8.8 Likely viva questions

| # | Question | Strong answer |
|---|---|---|
| 1 | Why BLoC over Provider/Riverpod? | Predictability + testability + async-stream-friendly. |
| 2 | `..checkAuth()` meaning? | Cascade — calls on new instance, returns instance. |
| 3 | Why feature-based folders? | Navigate, delete, scale. |
| 4 | Why mix Provider and BLoC? | ChangeNotifier lighter for toggle state. Acceptable trade-off. |
| 5 | Why ensureInitialized? | Platform channels must exist before Firebase/notifications. |
| 6 | firebase_options per platform? | FlutterFire CLI generates blocks; currentPlatform selects at runtime. |
| 7 | Where are API keys? | Envied compile-time obfuscation. |
| 8 | Is envied secure? | Obfuscation not encryption — extractable. True security = server proxy. |
| 9 | Why three auth states? | Prevents users skipping profile setup. |
| 10 | BlocConsumer? | BlocBuilder + BlocListener combined. |
| 11 | AnimatedTheme purpose? | 250ms cross-fade for dark mode. |
| 12 | Custom onGenerateRoute? | Uniform fade transitions. |
| 13 | `..add(LoadUserData())`? | Initiates async load at BLoC creation. |
| 14 | Adding Spanish? | Add app_es.arb, codegen, append Locale('es'). |
| 15 | Where is dark mode persisted? | shared_preferences in ThemeCubit. |
| 16 | If Firebase init fails? | App crashes on first auth call. Improvement: try/except + service-unavailable screen. |
| 17 | How are dark mode and locale composed? | ThemeCubit (Provider) + SettingsBloc orthogonal in nested builders. |
| 18 | Env.openaiApiKey? | Compile-time obfuscated constant from .env. |

## 8.9 Honest weaknesses

1. Mixed state management (Provider + BLoC).
2. No explicit DI beyond BLoC providers.
3. `'default_user'` placeholder is hacky.
4. No global error boundary.
5. Routes hard-coded; production should use go_router.
6. API keys obfuscated not encrypted.
