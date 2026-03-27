import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

/// Avatar emotion states for intelligent visual feedback
enum AvatarEmotion {
  neutral,
  listening,   // User is speaking - attentive pose
  thinking,    // Processing/generating response
  concerned,   // BP reading is concerning
  reassuring,  // BP is good/improving
  helpful,     // Providing health advice/recommendations
  analytical,  // Analyzing trends/comparisons
  informative, // Sharing factual health data
}

/// A 3D talking avatar widget that plays animations based on speaking state.
/// Uses glassmorphism styling for a modern, premium look.
/// 
/// Features:
/// - Speaking animation synced with TTS playback
/// - Listening state when user is recording
/// - Emotion-aware visual feedback (glow colors based on health status)
class TalkingAvatarWidget extends StatefulWidget {
  /// Whether the avatar is currently speaking (plays talking animation).
  final bool isSpeaking;
  
  /// Whether the avatar is listening to user input.
  final bool isListening;
  
  /// Current emotion state for visual feedback.
  final AvatarEmotion emotion;

  /// Callback when the 3D model has finished loading.
  final VoidCallback? onLoaded;

  /// Optional width for the container.
  final double width;

  /// Optional height for the container.
  final double height;

  const TalkingAvatarWidget({
    super.key,
    required this.isSpeaking,
    this.isListening = false,
    this.emotion = AvatarEmotion.neutral,
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
  
  // DEBUG MODE: Set to true to show camera adjustment controls
  // Once you find the right values, set to false and update the defaults below
  static const bool _debugMode = false;
  
  // Camera values - LOCKED IN based on user testing
  double _orbitTheta = 0;    // Horizontal rotation (0 = front)
  double _orbitPhi = 90;     // Vertical angle (90 = level view)
  double _orbitRadius = 2.0; // Distance from model
  double _targetY = 1.3;     // Vertical target point

  @override
  void initState() {
    super.initState();
    _controller.onModelLoaded.addListener(_onModelLoaded);
    // Check if model is already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onModelLoaded();
    });
  }

  void _onModelLoaded() {
    if (_controller.onModelLoaded.value && !_isLoaded) {
      setState(() {
        _isLoaded = true;
      });
      _fetchAnimations();
      widget.onLoaded?.call();
    }
  }

  Future<void> _fetchAnimations() async {
    try {
      // Get available animations (but don't auto-play them)
      _availableAnimations = await _controller.getAvailableAnimations();
      debugPrint('🎬 Available animations: $_availableAnimations');

      // Log and attempt to apply available textures
      // Some GLB files require explicit texture activation
      final textures = await _controller.getAvailableTextures();
      debugPrint('🖼️ Available textures: $textures');

      // Try to apply the first available texture if any exist
      // This can help with models where textures aren't auto-applied
      if (textures.isNotEmpty) {
        try {
          debugPrint('🎨 Attempting to apply texture: ${textures.first}');
          _controller.setTexture(textureName: textures.first);
          debugPrint('✅ Texture applied successfully');
        } catch (texError) {
          debugPrint('⚠️ Could not apply texture: $texError');
        }
      } else {
        debugPrint(
          'ℹ️ No explicit textures found - model may use embedded materials',
        );
      }

      // Play animation briefly then pause to get a good initial pose
      // This creates a "freeze frame" 1 second into the animation
      if (_availableAnimations != null && _availableAnimations!.isNotEmpty) {
        final anim = _availableAnimations!.first;
        debugPrint('🎭 Playing animation briefly for initial pose: $anim');
        _controller.playAnimation(animationName: anim);

        // Wait 1 second to let the animation reach a good frame, then pause
        await Future.delayed(const Duration(milliseconds: 1000));

        // Only pause if we're not supposed to be speaking
        if (!widget.isSpeaking) {
          _controller.pauseAnimation();
          debugPrint('⏸️ Animation paused at 1s mark for initial pose');
        } else {
          debugPrint('🗣️ Continuing animation - avatar is speaking');
        }
      }

      // Apply initial camera position using state variables
      _applyCamera();

      debugPrint('✅ Model ready');
    } catch (e) {
      debugPrint('❌ Error fetching animations/textures: $e');
    }
  }
  
  /// Apply camera settings and log values to console
  void _applyCamera() {
    _controller.setCameraOrbit(_orbitTheta, _orbitPhi, _orbitRadius);
    _controller.setCameraTarget(0, _targetY, 0);
    debugPrint('📷 CAMERA VALUES: orbit($_orbitTheta, $_orbitPhi, $_orbitRadius), targetY=$_targetY');
  }

  @override
  void didUpdateWidget(TalkingAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLoaded) return;
    
    // Prioritize states: Speaking > Listening > Idle
    final stateChanged = widget.isSpeaking != oldWidget.isSpeaking ||
                         widget.isListening != oldWidget.isListening;
    
    if (stateChanged) {
      if (widget.isSpeaking) {
        _playTalkingAnimation();
      } else if (widget.isListening) {
        _playListeningAnimation();
      } else {
        _playIdleAnimation();
      }
    }
  }
  
  /// Play a listening/attentive animation when user is speaking
  Future<void> _playListeningAnimation() async {
    if (_availableAnimations == null || _availableAnimations!.isEmpty) {
      debugPrint('⚠️ No animations available for listening');
      return;
    }
    
    // Try to find a listening/attentive animation
    final listeningAnim = _availableAnimations!.firstWhere((a) {
      final lower = a.toLowerCase();
      return lower.contains('listen') ||
          lower.contains('nod') ||
          lower.contains('attent') ||
          lower.contains('wait') ||
          lower.contains('idle');  // Fallback to idle for listening
    }, orElse: () => _availableAnimations!.first);
    
    debugPrint('👂 Playing listening animation: $listeningAnim');
    _controller.playAnimation(animationName: listeningAnim);
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

    // Try to find a dedicated idle animation by name
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
    } else {
      // No idle animation found — freeze on current frame rather than
      // continuously looping the talking animation.
      debugPrint('😌 No idle animation found, pausing at current frame');
      _controller.pauseAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Emotion-aware glow color
    Color? emotionGlowColor;
    switch (widget.emotion) {
      case AvatarEmotion.concerned:
        emotionGlowColor = const Color(0xFFEF5350); // Red for concern
        break;
      case AvatarEmotion.reassuring:
        emotionGlowColor = const Color(0xFF4CAF50); // Green for reassurance
        break;
      case AvatarEmotion.listening:
        emotionGlowColor = const Color(0xFF2196F3); // Blue for listening
        break;
      case AvatarEmotion.thinking:
        emotionGlowColor = const Color(0xFFFFA726); // Orange for thinking
        break;
      case AvatarEmotion.helpful:
        emotionGlowColor = const Color(0xFF9C27B0); // Purple for helpful
        break;
      case AvatarEmotion.analytical:
        emotionGlowColor = const Color(0xFF00BCD4); // Cyan for analytical
        break;
      case AvatarEmotion.informative:
        emotionGlowColor = const Color(0xFF607D8B); // Blue Grey for informative
        break;
      default:
        emotionGlowColor = null;
    }

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
          // Emotion-aware glow effect
          if (emotionGlowColor != null)
            BoxShadow(
              color: emotionGlowColor.withValues(alpha: 0.4),
              blurRadius: 25,
              spreadRadius: 3,
            ),
          // Speaking glow (takes priority over emotion glow)
          if (widget.isSpeaking)
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          // Listening pulse glow
          if (widget.isListening && !widget.isSpeaking)
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 1,
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
                // Using doctor_model.glb - has correct orientation
                // If textures don't appear, model may need re-export with embedded textures
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
              
              // DEBUG PANEL: Camera adjustment controls
              // Remove this entire block once you find the right values
              if (_debugMode && _isLoaded)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CAMERA DEBUG - Copy values to console',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        // Phi slider (vertical angle)
                        Row(
                          children: [
                            Text('φ:', style: TextStyle(color: Colors.white, fontSize: 10)),
                            Expanded(
                              child: Slider(
                                value: _orbitPhi,
                                min: 0,
                                max: 180,
                                onChanged: (v) {
                                  setState(() => _orbitPhi = v);
                                  _applyCamera();
                                },
                              ),
                            ),
                            Text('${_orbitPhi.toInt()}°', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                        // Radius slider (zoom)
                        Row(
                          children: [
                            Text('r:', style: TextStyle(color: Colors.white, fontSize: 10)),
                            Expanded(
                              child: Slider(
                                value: _orbitRadius,
                                min: 0.5,
                                max: 5.0,
                                onChanged: (v) {
                                  setState(() => _orbitRadius = v);
                                  _applyCamera();
                                },
                              ),
                            ),
                            Text(_orbitRadius.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                        // Target Y slider (vertical position)
                        Row(
                          children: [
                            Text('Y:', style: TextStyle(color: Colors.white, fontSize: 10)),
                            Expanded(
                              child: Slider(
                                value: _targetY,
                                min: -2.0,
                                max: 3.0,
                                onChanged: (v) {
                                  setState(() => _targetY = v);
                                  _applyCamera();
                                },
                              ),
                            ),
                            Text(_targetY.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ],
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
