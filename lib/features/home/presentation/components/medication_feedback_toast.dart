import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arteria/l10n/app_localizations.dart';

/// The kind of medication change being confirmed.
enum MedicationFeedbackAction { added, updated, switched }

/// A premium, animated confirmation toast shown when the assistant
/// successfully records a medication change (add / update / switch).
///
/// It slides down from the top as a heads-up card, matching the app's
/// design language — Inter type, dashboard surface colours, soft elevation —
/// adapts to light/dark themes, and is fully localized. It auto-dismisses
/// after a few seconds; the user can also swipe up or tap to dismiss early.
///
/// Use [MedicationFeedbackToast.show] with the backend `medication_feedback`
/// payload; it handles overlay insertion and lifecycle.
class MedicationFeedbackToast extends StatefulWidget {
  final MedicationFeedbackAction action;
  final String name;
  final String dosage;
  final String frequency;
  final List<Map<String, int>> times;
  final VoidCallback onDismissed;

  const MedicationFeedbackToast({
    super.key,
    required this.action,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.onDismissed,
  });

  /// The single toast currently on screen, if any.
  static OverlayEntry? _current;

  /// Parse a backend `medication_feedback` payload and present the toast.
  ///
  /// `feedback` is the map returned by the hybrid backend, e.g.
  /// `{action: "added", name: "telmisartan", dosage: "40mg",
  ///   frequency: "onceDaily", times: [{hour: 12, minute: 0}]}`.
  static void show(
    BuildContext context, {
    required Map<String, dynamic> feedback,
  }) {
    MedicationFeedbackAction parseAction(String? s) {
      switch (s) {
        case 'updated':
          return MedicationFeedbackAction.updated;
        case 'switched':
          return MedicationFeedbackAction.switched;
        default:
          return MedicationFeedbackAction.added;
      }
    }

    final times = <Map<String, int>>[];
    for (final t in (feedback['times'] as List? ?? const [])) {
      if (t is Map) {
        final h = (t['hour'] as num?)?.toInt();
        final m = (t['minute'] as num?)?.toInt() ?? 0;
        if (h != null && h >= 0 && h <= 23) {
          times.add({'hour': h, 'minute': m});
        }
      }
    }

    final overlay = Overlay.of(context);
    // Replace any toast still on screen so confirmations never stack.
    _current?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => MedicationFeedbackToast(
        action: parseAction(feedback['action']?.toString()),
        name: (feedback['name'] ?? '').toString(),
        dosage: (feedback['dosage'] ?? '').toString(),
        frequency: (feedback['frequency'] ?? 'onceDaily').toString(),
        times: times,
        onDismissed: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  @override
  State<MedicationFeedbackToast> createState() =>
      _MedicationFeedbackToastState();
}

class _MedicationFeedbackToastState extends State<MedicationFeedbackToast>
    with TickerProviderStateMixin {
  /// How long the toast stays fully visible before auto-dismissing.
  static const _visibleDuration = Duration(milliseconds: 4400);

  late final AnimationController _entry;
  late final AnimationController _progress;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _badgePop;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _progress = AnimationController(
      vsync: this,
      duration: _visibleDuration,
    );

    final curve = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(curve);
    _fade = curve;
    _badgePop = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.45, 1.0, curve: Curves.elasticOut),
    );

    _entry.forward();
    HapticFeedback.lightImpact();

    _progress.forward();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _dismiss();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _progress.stop();
    if (mounted) {
      await _entry.reverse();
    }
    widget.onDismissed();
  }

  /// Accent colour distinguishes the three actions at a glance.
  Color get _accent {
    switch (widget.action) {
      case MedicationFeedbackAction.added:
        return const Color(0xFF10B981); // emerald — matches med tracker card
      case MedicationFeedbackAction.updated:
        return const Color(0xFF6366F1); // indigo
      case MedicationFeedbackAction.switched:
        return const Color(0xFFF59E0B); // amber
    }
  }

  String _title(AppLocalizations l) {
    switch (widget.action) {
      case MedicationFeedbackAction.added:
        return l.medicationFeedbackAdded;
      case MedicationFeedbackAction.updated:
        return l.medicationFeedbackUpdated;
      case MedicationFeedbackAction.switched:
        return l.medicationFeedbackSwitched;
    }
  }

  String _frequencyLabel(AppLocalizations l) {
    switch (widget.frequency) {
      case 'twiceDaily':
        return l.frequencyTwiceDaily;
      case 'threeTimesDaily':
        return l.frequencyThreeTimesDaily;
      case 'onceDaily':
      default:
        return l.frequencyOnceDaily;
    }
  }

  String get _displayName {
    final n = widget.name.trim();
    if (n.isEmpty) return n;
    return n[0].toUpperCase() + n.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final accent = _accent;

    final surface = isDark ? const Color(0xFF1E1E24) : const Color(0xFFFAFAFC);
    final primaryText = isDark ? Colors.white : const Color(0xFF1E293B);
    final mutedText = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF64748B);

    // Primary detail: "Telmisartan  ·  40mg"
    final detailLine = widget.dosage.trim().isEmpty
        ? _displayName
        : '$_displayName  ·  ${widget.dosage.trim()}';

    // Secondary detail: "Once daily  ·  12:00 PM"
    final freqLabel = _frequencyLabel(l);
    String scheduleLine = freqLabel;
    if (widget.times.isNotEmpty) {
      final first = widget.times.first;
      final formatted = TimeOfDay(
        hour: first['hour']!,
        minute: first['minute'] ?? 0,
      ).format(context);
      scheduleLine = '$freqLabel  ·  $formatted';
    }

    return Positioned(
      top: media.padding.top + 8,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Align(
            alignment: Alignment.topCenter,
            child: Semantics(
              container: true,
              liveRegion: true,
              label: '${_title(l)}. $detailLine. $scheduleLine',
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  onTap: _dismiss,
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < 0) _dismiss();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxWidth: 460),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.24 : 0.20),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.45 : 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color:
                              accent.withValues(alpha: isDark ? 0.12 : 0.09),
                          blurRadius: 18,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(14, 14, 16, 13),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildIcon(accent, surface),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _title(l),
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        detailLine,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded,
                                              size: 12, color: mutedText),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              scheduleLine,
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: mutedText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildProgressBar(accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tinted rounded-square medication icon with an elastic check badge —
  /// the same icon treatment used on the medication tracker card.
  Widget _buildIcon(Color accent, Color surface) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.medication_rounded, size: 24, color: accent),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: ScaleTransition(
              scale: _badgePop,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thin bar that depletes over the visible duration — a quiet countdown
  /// so the dismiss never feels abrupt.
  Widget _buildProgressBar(Color accent) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        return Container(
          height: 3,
          color: accent.withValues(alpha: 0.12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (1.0 - _progress.value).clamp(0.0, 1.0),
              child: Container(color: accent.withValues(alpha: 0.9)),
            ),
          ),
        );
      },
    );
  }
}
