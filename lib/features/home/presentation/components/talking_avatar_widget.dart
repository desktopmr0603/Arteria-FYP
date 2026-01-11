import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

/// A 3D talking avatar widget that plays animations based on speaking state.
/// Uses glassmorphism styling for a modern, premium look.
class TalkingAvatarWidget extends StatefulWidget {
  /// Whether the avatar is currently speaking (plays talking animation).
  final bool isSpeaking;

  /// Callback when the 3D model has finished loading.
  final VoidCallback? onLoaded;

  /// Optional width for the container.
  final double width;

  /// Optional height for the container.
  final double height;

  const TalkingAvatarWidget({
    super.key,
    required this.isSpeaking,
    this.onLoaded,
    this.width = 300,
    this.height = 400,
  });

  @override
  State<TalkingAvatarWidget> createState() => _TalkingAvatarWidgetState();
}

class _TalkingAvatarWidgetState extends State<TalkingAvatarWidget>
    with SingleTickerProviderStateMixin {
  final Flutter3DController _controller = Flutter3DController();
  bool _isLoaded = false;
  List<String>? _availableAnimations;

  @override
  void initState() {
    super.initState();
    _controller.onModelLoaded.addListener(_onModelLoaded);
  }

  void _onModelLoaded() {
    if (_controller.onModelLoaded.value && !_isLoaded) {
      _isLoaded = true;
      _fetchAnimations();
      widget.onLoaded?.call();
    }
  }

  Future<void> _fetchAnimations() async {
    try {
      // Get available animations (but don't auto-play them)
      _availableAnimations = await _controller.getAvailableAnimations();
      debugPrint('🎬 Available animations: $_availableAnimations');

      // Log available textures for debugging
      // Note: GLB files with embedded textures should auto-apply them
      final textures = await _controller.getAvailableTextures();
      debugPrint('🖼️ Available textures: $textures');

      // DO NOT auto-play any animation on load
      // The avatar should remain static until isSpeaking becomes true
      // This prevents the talking animation from playing during loading
      debugPrint('⏸️ Model loaded - waiting for isSpeaking to start animation');

      // Check current speaking state in case it was set before load completed
      if (widget.isSpeaking) {
        _playTalkingAnimation();
      }
    } catch (e) {
      debugPrint('❌ Error fetching animations/textures: $e');
    }
  }

  @override
  void didUpdateWidget(TalkingAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking && _isLoaded) {
      widget.isSpeaking ? _playTalkingAnimation() : _playIdleAnimation();
    }
  }

  Future<void> _playTalkingAnimation() async {
    if (_availableAnimations == null || _availableAnimations!.isEmpty) {
      debugPrint('⚠️ No animations available for talking');
      return;
    }

    // Try to find a talking animation by name (various naming conventions)
    final talkingAnim = _availableAnimations!.firstWhere((a) {
      final lower = a.toLowerCase();
      return lower.contains('talk') ||
          lower.contains('speak') ||
          lower.contains('mouth') ||
          lower.contains('say') ||
          lower.contains('voice') ||
          lower.contains('lip') ||
          lower.contains('chat');
    }, orElse: () => _availableAnimations!.first);

    debugPrint('🗣️ Playing talking animation: $talkingAnim');
    _controller.playAnimation(animationName: talkingAnim);
  }

  Future<void> _playIdleAnimation() async {
    if (_availableAnimations == null || _availableAnimations!.isEmpty) {
      debugPrint('⚠️ No animations available for idle');
      _controller.pauseAnimation();
      return;
    }

    // Try to find an idle animation by various names
    final idleAnim = _availableAnimations!.firstWhere((a) {
      final lower = a.toLowerCase();
      return lower.contains('idle') ||
          lower.contains('stand') ||
          lower.contains('rest') ||
          lower.contains('breathe') ||
          lower.contains('wait') ||
          lower.contains('default');
    }, orElse: () => '');

    if (idleAnim.isNotEmpty) {
      debugPrint('😌 Playing idle animation: $idleAnim');
      _controller.playAnimation(animationName: idleAnim);
    } else if (_availableAnimations!.isNotEmpty) {
      // Fallback: play the first animation but at slower pace
      debugPrint(
        '😌 No idle found, playing first animation: ${_availableAnimations!.first}',
      );
      _controller.playAnimation(animationName: _availableAnimations!.first);
    } else {
      _controller.pauseAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Glassmorphism gradient background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ]
              : [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.3),
                ],
        ),
        // Subtle border for glass effect
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (widget.isSpeaking)
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              // 3D Avatar
              Flutter3DViewer(
                controller: _controller,
                src: 'assets/models/model.glb',
                progressBarColor: Theme.of(context).primaryColor,
              ),

              // Loading overlay
              if (!_isLoaded)
                Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Avatar...',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Speaking indicator glow effect
              if (widget.isSpeaking && _isLoaded)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq,
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Speaking...',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.onModelLoaded.removeListener(_onModelLoaded);
    super.dispose();
  }
}
