import 'package:arteria/features/auth/presentation/components/custom_confirmdialog.dart';
import 'package:arteria/features/auth/presentation/components/custom_textfield.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool rememberMe = false;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late final authCubit = context.read<AuthCubits>();

  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submitLogin() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Ensure both email and password are filled"),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    authCubit.login(email, password);
  }

  void openForgotPasswordBox() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFF9FAFB),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Forgot Password",
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailCtrl,
                  label: "Enter your email...",
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "CANCEL",
                        style: GoogleFonts.openSans(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE63946),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        String message = await authCubit.forgotPassword(
                          _emailCtrl.text,
                        );

                        if (!context.mounted) return;

                        if (message ==
                            "Password reset email sent! Check your inbox.") {
                          Navigator.pop(context);
                          _emailCtrl.clear();
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: const Color(0xFFE63946),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "RESET",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    context.read<AuthCubits>().signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    // Local fixed theme for the login page (not affected by ThemeCubit)
    final ThemeData loginTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE63946),
        secondary: Color(0xFFB33939),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A1A),
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: const Color(0xFF1A1A1A),
        displayColor: const Color(0xFF1A1A1A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE63946),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );

    return Theme(
      data: loginTheme,
      child: BlocListener<AuthCubits, AuthStates>(
        listener: (context, state) {
          // Dismiss loading dialog when state changes from AuthLoading
          if (state is! AuthLoading) {
            // Try to pop the loading dialog if it exists
            Navigator.of(context, rootNavigator: true).popUntil((route) {
              // Keep popping until we reach a non-dialog route or can't pop anymore
              return route.isFirst || route is! DialogRoute;
            });
          }

          if (state is AuthLoading) {
            showDialog(
              context: context,
              barrierDismissible: false,
              useRootNavigator: true,
              builder: (_) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE63946)),
                ),
              ),
            );
          } else if (state is Authenticated) {
            Navigator.pushReplacementNamed(context, '/');
          } else if (state is AuthenticatedNeedsProfileSetup) {
            Navigator.pushReplacementNamed(context, '/profile-setup');
          } else if (state is AuthError) {
            final message = state.message;
            final isGoogleSignInError =
                message.toLowerCase().contains('google sign-in');
            if (!isGoogleSignInError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: const Color(0xFFE63946),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } else if (state is AuthCredentialError) {
            // Handle specific credential errors (incorrect email/password)
            String errorMessage = state.generalError ??
                state.emailError ??
                state.passwordError ??
                'Login failed. Please check your credentials.';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: const Color(0xFFE63946),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            final bool shouldPop =
                await showDialog<bool>(
                  context: context,
                  builder: (context) => const CustomConfirmDialog(
                    title: 'Go back?',
                    content: 'Are you sure you want to go back?',
                    confirmText: 'GO BACK',
                  ),
                ) ??
                false;
            if (shouldPop && context.mounted) {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
          child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFDECEC),
                  Color(0xFFE8F0FF),
                  Color(0xFFF9FAFB),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      "Welcome back!",
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Log in to continue monitoring with Arteria",
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        color: const Color(0xFF4B4B4B),
                      ),
                    ),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _emailCtrl,
                      label: "Email",
                      icon: Icons.email_outlined,
                      focusNode: _emailFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    CustomPasswordField(
                      controller: _passwordCtrl,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isVisible: _passwordVisible,
                      onToggleVisibility: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      focusNode: _passwordFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitLogin(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              activeColor: const Color(0xFFE63946),
                              onChanged: (val) {
                                setState(() {
                                  rememberMe = val ?? false;
                                });
                              },
                            ),
                            const Text("Remember me"),
                          ],
                        ),
                        TextButton(
                          onPressed: openForgotPasswordBox,
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Color(0xFFE63946)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          minimumSize: const Size.fromHeight(55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          "Login",
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text("Or continue with"),
                        ),
                        Expanded(child: Divider(thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE63946)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: Image.asset(
                          'assets/google.png',
                          height: 24,
                          width: 24,
                        ),
                        label: Text(
                          "Continue with Google",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFFE63946),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: GoogleFonts.openSans(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/signup');
                          },
                          child: Text(
                            "Sign up",
                            style: GoogleFonts.openSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE63946),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
