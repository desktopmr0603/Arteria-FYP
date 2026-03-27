import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Re-export types from bloc to avoid duplication
import '../bloc/health_notifications_bloc.dart';

/// Health Notification Card Widget
/// 
/// Displays health alerts and notifications with modern UI design
/// and interactive elements for user engagement.
class HealthNotificationCard extends StatefulWidget {
  final String title;
  final String message;
  final String timestamp;
  final NotificationType type;
  final NotificationPriority priority;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionText;

  const HealthNotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.priority,
    this.onTap,
    this.onDismiss,
    this.onAction,
    this.actionText,
  });

  @override
  State<HealthNotificationCard> createState() => _HealthNotificationCardState();
}

class _HealthNotificationCardState extends State<HealthNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.forward().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value * 400, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(isDark),
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getBorderColor(isDark),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getShadowColor(isDark),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 12),
                        _buildMessage(isDark),
                        if (_isExpanded) ...[
                          const SizedBox(height: 12),
                          _buildExpandedContent(isDark),
                        ],
                        const SizedBox(height: 12),
                        _buildFooter(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getIconColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIcon(),
            color: _getIconColor(),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                widget.timestamp,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildPriorityBadge(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessage(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (!_isExpanded && widget.message.length > 100)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Read more...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _getIconColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getDetailedMessage(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            const SizedBox(width: 4),
            Text(
              _getTypeDisplayName(),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        if (widget.onAction != null && widget.actionText != null)
          ElevatedButton(
            onPressed: widget.onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getIconColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              widget.actionText!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriorityBadge() {
    Color color;
    String text;
    
    switch (widget.priority) {
      case NotificationPriority.critical:
        color = const Color(0xFFDC2626);
        text = 'Critical';
        break;
      case NotificationPriority.high:
        color = const Color(0xFFEF4444);
        text = 'High';
        break;
      case NotificationPriority.medium:
        color = const Color(0xFFF59E0B);
        text = 'Medium';
        break;
      case NotificationPriority.low:
        color = const Color(0xFF10B981);
        text = 'Low';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  List<Color> _getGradientColors(bool isDark) {
    switch (widget.type) {
      case NotificationType.riskChange:
        return [
          const Color(0xFFEF4444).withOpacity(isDark ? 0.1 : 0.05),
          const Color(0xFFDC2626).withOpacity(isDark ? 0.05 : 0.02),
        ];
      case NotificationType.anomaly:
        return [
          const Color(0xFFF59E0B).withOpacity(isDark ? 0.1 : 0.05),
          const Color(0xFFD97706).withOpacity(isDark ? 0.05 : 0.02),
        ];
      case NotificationType.medication:
        return [
          const Color(0xFF3B82F6).withOpacity(isDark ? 0.1 : 0.05),
          const Color(0xFF2563EB).withOpacity(isDark ? 0.05 : 0.02),
        ];
      case NotificationType.trend:
        return [
          const Color(0xFF8B5CF6).withOpacity(isDark ? 0.1 : 0.05),
          const Color(0xFF7C3AED).withOpacity(isDark ? 0.05 : 0.02),
        ];
      case NotificationType.summary:
        return [
          const Color(0xFF10B981).withOpacity(isDark ? 0.1 : 0.05),
          const Color(0xFF059669).withOpacity(isDark ? 0.05 : 0.02),
        ];
    }
  }

  Color _getBorderColor(bool isDark) {
    return _getIconColor().withValues(alpha: isDark ? 0.3 : 0.2);
  }

  Color _getShadowColor(bool isDark) {
    return _getIconColor().withValues(alpha: isDark ? 0.2 : 0.1);
  }

  Color _getIconColor() {
    switch (widget.type) {
      case NotificationType.riskChange:
        return const Color(0xFFEF4444);
      case NotificationType.anomaly:
        return const Color(0xFFF59E0B);
      case NotificationType.medication:
        return const Color(0xFF3B82F6);
      case NotificationType.trend:
        return const Color(0xFF8B5CF6);
      case NotificationType.summary:
        return const Color(0xFF10B981);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.riskChange:
        return Icons.trending_up;
      case NotificationType.anomaly:
        return Icons.warning;
      case NotificationType.medication:
        return Icons.medication;
      case NotificationType.trend:
        return Icons.show_chart;
      case NotificationType.summary:
        return Icons.summarize;
    }
  }

  String _getTypeDisplayName() {
    switch (widget.type) {
      case NotificationType.riskChange:
        return 'Risk Change';
      case NotificationType.anomaly:
        return 'Anomaly Alert';
      case NotificationType.medication:
        return 'Medication';
      case NotificationType.trend:
        return 'Trend Analysis';
      case NotificationType.summary:
        return 'Daily Summary';
    }
  }

  String _getDetailedMessage() {
    switch (widget.type) {
      case NotificationType.riskChange:
        return 'Your health risk score has changed significantly. This could be due to recent lifestyle changes, medication adherence, or other health factors. Consider reviewing your recent health data and consult with your healthcare provider if needed.';
      case NotificationType.anomaly:
        return 'An unusual pattern has been detected in your blood pressure readings. This could indicate temporary stress, measurement error, or a genuine health concern. Take another reading to confirm and monitor closely.';
      case NotificationType.medication:
        return 'Medication adherence is crucial for managing your blood pressure effectively. Missing doses can lead to fluctuations in your readings and reduce the effectiveness of your treatment plan.';
      case NotificationType.trend:
        return 'Your blood pressure has shown a consistent trend over the past week. Understanding these patterns can help you and your healthcare provider make informed decisions about your treatment strategy.';
      case NotificationType.summary:
        return 'This is your daily health summary, providing an overview of your key health metrics and recent activities. Use this information to track your progress and identify areas for improvement.';
    }
  }
}
