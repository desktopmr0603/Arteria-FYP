import 'package:arteria/Core/Theme/theme_cubit.dart';
import 'package:arteria/features/auth/data/firebase_auth_repo.dart';
import 'package:arteria/features/auth/presentation/components/loading.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:arteria/features/auth/presentation/pages/onboarding_screen.dart';
import 'package:arteria/features/auth/presentation/pages/login_page.dart';
import 'package:arteria/features/auth/presentation/pages/profile_setup_screen.dart';
import 'package:arteria/features/auth/presentation/pages/signup_page.dart';
import 'package:arteria/features/home/presentation/homepage.dart';
import 'package:arteria/features/settings/settings_bloc.dart';
import 'package:arteria/features/user%20data/user_bloc.dart';
import 'package:arteria/features/user%20data/user_event.dart';
import 'package:arteria/Core/Theme/app_theme.dart';
import 'package:arteria/firebase_options.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:arteria/env/env.dart'; // Import the Env class

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    return ChangeNotifierProvider(
      create: (_) => ThemeCubit(),
      child: Consumer<ThemeCubit>(
        builder: (context, themeCubit, _) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubits>(
                create: (context) =>
                    AuthCubits(authRepo: FirebaseAuthRepo())..checkAuth(),
              ),
              BlocProvider<UserBloc>(
                create: (context) => UserBloc()..add(LoadUserData()),
              ),
              BlocProvider<SettingsBloc>(create: (context) => SettingsBloc()),
            ],
            child: AnimatedTheme(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              data: themeCubit.isDarkMode ? darkTheme : lightTheme,
              child: MaterialApp(
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
            ),
          );
        },
      ),
    );
  }
}

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
        return const Loading();
      },
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
