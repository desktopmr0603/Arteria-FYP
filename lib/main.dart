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

/// Application entry point - initializes all required services before app starts
Future<void> main() async {
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

  // Health push notifications are evaluated against the *authenticated* user —
  // on app open and after each reading is saved via
  // HealthNotificationService.runChecksForCurrentUser(). There is no signed-in
  // user this early in startup, so nothing is initialized here.

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
                    onGenerateRoute: (settings) {
                      final routes = <String, WidgetBuilder>{
                        '/': (_) => const _AuthWrapper(),
                        '/login': (_) => const LoginPage(),
                        '/signup': (_) => const SignupPage(),
                        '/profile-setup': (_) => const ProfileSetupScreen(),
                      };
                      final builder = routes[settings.name];
                      if (builder == null) return null;
                      return PageRouteBuilder(
                        settings: settings,
                        pageBuilder: (ctx, _, __) => builder(ctx),
                        transitionDuration: const Duration(milliseconds: 300),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 250,
                        ),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          );
                        },
                      );
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
