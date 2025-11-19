import 'package:arteria/features/auth/presentation/components/custom_confirmdialog.dart';
import 'package:arteria/features/auth/presentation/components/custom_snackbar.dart';
import 'package:arteria/features/auth/presentation/components/custom_textfield.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // Focus Nodes
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // Visibility and validation flags
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _agreeToTerms = false;

  bool _passwordsMatch = true;
  bool _emailValid = true;
  bool _passwordValid = true;

  // Progressive reveal flags
  bool _showPasswordField = false;
  bool _showConfirmPasswordField = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-0.02, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.02, 0), end: const Offset(0.02, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.02, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(_animationController);

    // Add listeners for progressive reveal
    _emailCtrl.addListener(_onEmailChanged);
    _passwordCtrl.addListener(_onPasswordChanged);
  }

  void _onEmailChanged() {
    final email = _emailCtrl.text.trim();
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[a-z]{2,}$");
    final shouldShow = email.isNotEmpty && emailRegex.hasMatch(email);
    
    if (shouldShow != _showPasswordField) {
      setState(() {
        _showPasswordField = shouldShow;
        if (!shouldShow) {
          _showConfirmPasswordField = false;
        }
      });
    }
  }

  void _onPasswordChanged() {
    final password = _passwordCtrl.text;
    final shouldShow = password.length >= 8;
    
    if (shouldShow != _showConfirmPasswordField) {
      setState(() {
        _showConfirmPasswordField = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    _animationController.dispose();
    super.dispose();
  }

  /// Handles user registration validation and submission
  void _register() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[a-z]{2,}$");
    final passwordRegex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{8,}$');

    setState(() {
      _emailValid = true;
      _passwordValid = true;
      _passwordsMatch = true;
    });

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      CustomSnackBar.show(context, "Please fill in all fields.");
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailValid = false);
      CustomSnackBar.show(context, "Please enter a valid email address.");
      return;
    }

    if (password != confirmPassword) {
      setState(() => _passwordsMatch = false);
      _animationController.forward(from: 0);
      CustomSnackBar.show(context, "Passwords do not match.");
      return;
    }

    if (!passwordRegex.hasMatch(password)) {
      setState(() => _passwordValid = false);
      CustomSnackBar.show(
        context,
        "Password must be at least 8 characters and include letters and numbers.",
      );
      return;
    }

    if (!_agreeToTerms) {
      CustomSnackBar.show(
        context,
        "You must agree to the Terms and Conditions.",
      );
      return;
    }

    context.read<AuthCubits>().register(firstName, lastName, email, password);
  }

  @override
  Widget build(BuildContext context) {
    // Fixed light theme for the signup page only (ignores ThemeCubit)
    final ThemeData signupTheme = ThemeData.light().copyWith(
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
      data: signupTheme,
      child: BlocListener<AuthCubits, AuthStates>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.pushReplacementNamed(context, '/');
          } else if (state is AuthenticatedNeedsProfileSetup) {
            Navigator.pushReplacementNamed(context, '/profile-setup');
          } else if (state is AuthError) {
            CustomSnackBar.show(context, state.message);
          }
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, String? result) async {
            if (didPop) return;

            final bool shouldPop =
                await showDialog<bool>(
                  context: context,
                  builder: (context) => const CustomConfirmDialog(
                    title: 'Discard changes?',
                    content: 'Are you sure you want to leave without saving?',
                  ),
                ) ??
                false;

            if (shouldPop && context.mounted) {
              Navigator.of(context).pushNamed('/');
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
                      const SizedBox(height: 30),
                      Text(
                        "Create Account",
                        style: GoogleFonts.montserrat(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Start monitoring with Arteria",
                        style: GoogleFonts.openSans(
                          fontSize: 15,
                          color: const Color(0xFF4B4B4B),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // First Name
                      CustomTextField(
                        controller: _firstNameCtrl,
                        label: "First Name",
                        icon: Icons.person_outline,
                        focusNode: _firstNameFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _lastNameFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      CustomTextField(
                        controller: _lastNameCtrl,
                        label: "Last Name",
                        icon: Icons.person_outline,
                        focusNode: _lastNameFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),


                      // Email
                      CustomTextField(
                        controller: _emailCtrl,
                        label: "Email",
                        icon: Icons.email_outlined,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          if (_showPasswordField) {
                            _passwordFocus.requestFocus();
                          }
                        },
                        isError: !_emailValid,
                      ),
                      
                      // Helper text for email
                      if (!_showPasswordField && _emailCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            "Please enter a valid email address",
                            style: GoogleFonts.openSans(
                              fontSize: 12,
                              color: const Color(0xFFE63946),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      
                      // Password - Progressive Reveal
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showPasswordField ? 1.0 : 0.0,
                          child: _showPasswordField
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),
                                    CustomPasswordField(
                                      controller: _passwordCtrl,
                                      label: "Password",
                                      icon: Icons.lock_outline,
                                      isVisible: _passwordVisible,
                                      onToggleVisibility: () => setState(
                                        () => _passwordVisible = !_passwordVisible,
                                      ),
                                      focusNode: _passwordFocus,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) {
                                        if (_showConfirmPasswordField) {
                                          _confirmPasswordFocus.requestFocus();
                                        }
                                      },
                                      isError: !_passwordValid,
                                    ),
                                    // Password strength indicator
                                    if (_passwordCtrl.text.isNotEmpty && !_showConfirmPasswordField)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8, left: 12),
                                        child: Text(
                                          "Password must be at least 8 characters",
                                          style: GoogleFonts.openSans(
                                            fontSize: 12,
                                            color: _passwordCtrl.text.length >= 8
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFE63946),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      // Confirm Password - Progressive Reveal
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showConfirmPasswordField ? 1.0 : 0.0,
                          child: _showConfirmPasswordField
                              ? Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    SlideTransition(
                                      position: _slideAnimation,
                                      child: CustomPasswordField(
                                        controller: _confirmPasswordCtrl,
                                        label: "Confirm Password",
                                        icon: Icons.lock,
                                        isVisible: _confirmPasswordVisible,
                                        onToggleVisibility: () => setState(
                                          () => _confirmPasswordVisible =
                                              !_confirmPasswordVisible,
                                        ),
                                        focusNode: _confirmPasswordFocus,
                                        isError: !_passwordsMatch,
                                        errorText: _passwordsMatch
                                            ? null
                                            : "Passwords do not match",
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Terms and Conditions
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            activeColor: const Color(0xFFE63946),
                            onChanged: (val) =>
                                setState(() => _agreeToTerms = val ?? false),
                          ),
                          Expanded(
                            child: Text(
                              "I agree to the Terms and Conditions",
                              style: GoogleFonts.openSans(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE63946),
                            minimumSize: const Size.fromHeight(55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            "Sign Up",
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider with text
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

                      // Google Sign-In
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<AuthCubits>().signInWithGoogle();
                        },
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
                      const SizedBox(height: 24),

                      // Already Have an Account
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.openSans(
                              fontSize: 14,
                              color: const Color(0xFF4B4B4B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              "Log in",
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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
