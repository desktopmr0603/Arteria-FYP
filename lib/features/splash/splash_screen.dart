import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _showChild = false;
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Remove native splash after the first frame so the Flutter splash is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_nativeSplashRemoved) {
        FlutterNativeSplash.remove();
        _nativeSplashRemoved = true;
      }
    });

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _showChild = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _showChild
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : Scaffold(
              key: const ValueKey('splash'),
              backgroundColor: bgColor,
              body: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SvgPicture.asset(
                      'assets/illustrations/Arteria_Logo.svg',
                      width: 120,
                      height: 120,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFEF6461),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
