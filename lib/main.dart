import 'package:arteria/Core/Theme/theme_cubit.dart';
import 'package:arteria/features/auth/data/firebase_auth_repo.dart';
import 'package:arteria/features/auth/presentation/components/loading.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:arteria/features/auth/presentation/pages/onboarding_screen.dart';
import 'package:arteria/features/auth/presentation/pages/login_page.dart';
import 'package:arteria/features/auth/presentation/pages/profile_setup_screen.dart';
import 'package:arteria/features/auth/presentation/pages/signup_page.dart';
import 'package:arteria/features/home/presentation/pages/homepage/homepage.dart';
import 'package:arteria/features/home/presentation/pages/settings/bloc/settings_bloc.dart';
import 'package:arteria/features/home/presentation/pages/settings/bloc/settings_state.dart';
import 'package:arteria/features/reminders/reminder_bloc.dart';
import 'package:arteria/features/reminders/reminder_event.dart';
import 'package:arteria/features/reminders/reminder_service.dart';
import 'package:arteria/features/user%20data/user_bloc.dart';
import 'package:arteria/features/user%20data/user_event.dart';
import 'package:arteria/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:arteria/Core/Theme/app_theme.dart';
import 'package:arteria/firebase_options.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:arteria/env/env.dart';
import 'package:arteria/services/health_notification_service.dart';
import 'package:arteria/features/home/data/data_sources/health_risk_score_service.dart';
import 'package:arteria/features/home/data/data_sources/bp_anomaly_remote_data_source.dart';

/// Application entry point - initializes all required services before app starts
Future<void> main() async {
  // Required for async operations before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pre-initialize Google Sign-In to avoid delays on first use
  // Non-critical - will retry if needed during actual sign-in
  try {
    await FirebaseAuthRepo.initGoogleSignIn();
    debugPrint('Google Sign-In initialized');
  } catch (e) {
    debugPrint('Google Sign-In init failed (will retry on use): $e');
  }

  // Set up local notification system for medication reminders
  await ReminderService().initialize();

  // Initialize health monitoring services with placeholder user ID
  // Will be updated with real user ID after authentication
  try {
    final riskScoreService = HealthRiskScoreService();
    final anomalyService = BPAnomalyRemoteDataSource();

    await riskScoreService.initialize();
    await anomalyService.initialize('default_user');

    final notificationService = HealthNotificationService(
      userId: 'default_user',
      riskScoreService: riskScoreService,
      anomalyService: anomalyService,
    );

    await notificationService.initialize();
    debugPrint('Health Notification Service initialized');
  } catch (e) {
    debugPrint('Health Notification Service init failed: $e');
  }

  // Configure API keys for external services such as OpenAI, RunPod
  try {
    OpenAI.apiKey = Env.openaiApiKey;
    final runpodKey = Env.runpodApiKey;
    debugPrint('RunPod API Key: $runpodKey');
  } catch (e) {
    debugPrint('Error initializing API keys: $e');
  }

  runApp(const MyApp());
}

/// Root widget - sets up state management and theming infrastructure
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeCubit uses ChangeNotifier pattern (Provider)
    return ChangeNotifierProvider(
      create: (_) => ThemeCubit(),
      child: Consumer<ThemeCubit>(
        builder: (context, themeCubit, _) {
          // All BLoCs use Bloc pattern - centralized here for app-wide access
          return MultiBlocProvider(
            providers: [
              // Authentication - checks existing session on startup
              BlocProvider<AuthCubits>(
                create: (context) =>
                    AuthCubits(authRepo: FirebaseAuthRepo())..checkAuth(),
              ),
              // User profile data
              BlocProvider<UserBloc>(
                create: (context) => UserBloc()..add(LoadUserData()),
              ),
              // App settings (language, units, etc.)
              BlocProvider<SettingsBloc>(create: (context) => SettingsBloc()),
              // Medication reminders
              BlocProvider<ReminderBloc>(
                create: (context) => ReminderBloc()..add(LoadReminders()),
              ),
              // Blood pressure trends and analytics
              BlocProvider<TrendsBloc>(create: (context) => TrendsBloc()),
            ],
            child: BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                debugPrint(
                  'Current locale: ${settingsState.locale.languageCode}',
                );

                // AnimatedTheme provides smooth transition when toggling dark mode
                return AnimatedTheme(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  data: themeCubit.isDarkMode ? darkTheme : lightTheme,
                  child: MaterialApp(
                    // Localization setup for multi-language support
                    localizationsDelegates: [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: [Locale('en'), Locale('fr')],
                    locale: settingsState.locale,
                    debugShowCheckedModeBanner: false,
                    title: 'Arteria',
                    theme: lightTheme,
                    darkTheme: darkTheme,
                    themeMode: themeCubit.isDarkMode
                        ? ThemeMode.dark
                        : ThemeMode.light,
                    routes: {
                      '/': (context) => const _AuthWrapper(),
                      '/login': (context) => const LoginPage(),
                      '/signup': (context) => const SignupPage(),
                      '/profile-setup': (context) => const ProfileSetupScreen(),
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Routes user to appropriate screen based on authentication state
/// Acts as a single source of truth for navigation logic:
/// Not logged in -> Onboarding
/// Logged in but no profile -> Profile Setup
/// Fully authenticated -> Homepage
class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubits, AuthStates>(
      builder: (context, state) {
        if (state is Unauthenticated) {
          return const OnboardingScreen();
        } else if (state is Authenticated) {
          return const Homepage();
        } else if (state is AuthenticatedNeedsProfileSetup) {
          return const ProfileSetupScreen();
        }
        // Default: show loading while checking auth state
        return const Loading();
      },
      // Show auth errors (e.g., network issues, invalid credentials) to user
      listener: (context, state) {
        if (state is AuthError && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
    );
  }
}
