import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/health_notification_card.dart';
import '../bloc/health_notifications_bloc.dart';

/// Health Notifications Screen
/// 
/// Displays all health notifications and alerts in a comprehensive
/// and organized interface with filtering and management options.
class HealthNotificationsScreen extends StatefulWidget {
  const HealthNotificationsScreen({super.key});

  @override
  State<HealthNotificationsScreen> createState() => _HealthNotificationsScreenState();
}

class _HealthNotificationsScreenState extends State<HealthNotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  NotificationFilter _currentFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Load notifications
    context.read<HealthNotificationsBloc>().add(LoadHealthNotifications());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8FAFB),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildFilterTabs(isDark),
          _buildFilterChips(isDark),
          Expanded(
            child: BlocBuilder<HealthNotificationsBloc, HealthNotificationsState>(
              builder: (context, state) {
                if (state is HealthNotificationsLoading) {
                  return _buildLoadingState(isDark);
                } else if (state is HealthNotificationsLoaded) {
                  final filteredNotifications = _filterNotifications(state.notifications);
                  return _buildNotificationsList(filteredNotifications, isDark);
                } else if (state is HealthNotificationsError) {
                  return _buildErrorState(state.message, isDark);
                }
                return _buildEmptyState(isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8FAFB),
      elevation: 0,
      title: Text(
        'Health Notifications',
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            context.read<HealthNotificationsBloc>().add(ClearAllNotifications());
          },
          icon: Icon(
            Icons.clear_all,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        IconButton(
          onPressed: () {
            _showSettingsDialog();
          },
          icon: Icon(
            Icons.settings,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF6366F1),
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        indicatorColor: const Color(0xFF6366F1),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Critical'),
          Tab(text: 'High'),
          Tab(text: 'Medium'),
          Tab(text: 'Low'),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Risk'),
          Tab(text: 'Anomaly'),
          Tab(text: 'Medication'),
          Tab(text: 'Trend'),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', NotificationFilter.all, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Today', NotificationFilter.today, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Week', NotificationFilter.week, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Unread', NotificationFilter.unread, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Resolved', NotificationFilter.resolved, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, NotificationFilter filter, bool isDark) {
    final isSelected = _currentFilter == filter;
    
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = filter;
        });
      },
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.1),
      selectedColor: const Color(0xFF6366F1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<HealthNotification> notifications, bool isDark) {
    if (notifications.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HealthNotificationsBloc>().add(LoadHealthNotifications());
      },
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return HealthNotificationCard(
            title: notification.title,
            message: notification.message,
            timestamp: _formatTimestamp(notification.timestamp),
            type: notification.type,
            priority: notification.priority,
            onTap: () {
              _markAsRead(notification.id);
            },
            onDismiss: () {
              _dismissNotification(notification.id);
            },
            onAction: notification.actionText != null
                ? () {
                    _handleNotificationAction(notification);
                  }
                : null,
            actionText: notification.actionText,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 64,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up! Health notifications will appear here.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading notifications',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<HealthNotificationsBloc>().add(LoadHealthNotifications());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddNotificationDialog();
      },
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(
        'Test',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<HealthNotification> _filterNotifications(List<HealthNotification> notifications) {
    var filtered = notifications;

    // Filter by tab (priority)
    final tabIndex = _tabController.index;
    if (tabIndex > 0) {
      final priorities = [
        [NotificationPriority.critical],
        [NotificationPriority.high],
        [NotificationPriority.medium],
        [NotificationPriority.low],
      ];
      if (tabIndex <= priorities.length) {
        filtered = filtered.where((n) => priorities[tabIndex - 1].contains(n.priority)).toList();
      }
    }

    // Filter by type (secondary tabs)
    final typeTabIndex = _tabController.index;
    if (typeTabIndex > 0) {
      final types = [
        [NotificationType.riskChange],
        [NotificationType.anomaly],
        [NotificationType.medication],
        [NotificationType.trend],
      ];
      if (typeTabIndex <= types.length) {
        filtered = filtered.where((n) => types[typeTabIndex - 1].contains(n.type)).toList();
      }
    }

    // Filter by time/status
    final now = DateTime.now();
    switch (_currentFilter) {
      case NotificationFilter.today:
        filtered = filtered.where((n) {
          final difference = now.difference(n.timestamp);
          return difference.inDays == 0;
        }).toList();
        break;
      case NotificationFilter.week:
        filtered = filtered.where((n) {
          final difference = now.difference(n.timestamp);
          return difference.inDays <= 7;
        }).toList();
        break;
      case NotificationFilter.unread:
        filtered = filtered.where((n) => !n.isRead).toList();
        break;
      case NotificationFilter.resolved:
        filtered = filtered.where((n) => n.isResolved).toList();
        break;
      case NotificationFilter.all:
        break;
    }

    return filtered..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _markAsRead(String notificationId) {
    context.read<HealthNotificationsBloc>().add(MarkNotificationAsRead(notificationId));
  }

  void _dismissNotification(String notificationId) {
    context.read<HealthNotificationsBloc>().add(DismissNotification(notificationId));
  }

  void _handleNotificationAction(HealthNotification notification) {
    // Handle notification-specific actions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: ${notification.actionText}'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(
                'Critical Alerts',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              subtitle: Text(
                'Immediate notifications for critical health events',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text(
                'Daily Summary',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              subtitle: Text(
                'Receive daily health summary at 8 PM',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text(
                'Medication Reminders',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              subtitle: Text(
                'Remind me to take medications on time',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Test Notification',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will add a test notification for demonstration purposes.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addTestNotification();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Add',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _addTestNotification() {
    final testNotification = HealthNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Test Notification',
      message: 'This is a test notification to demonstrate the notification system functionality.',
      timestamp: DateTime.now(),
      type: NotificationType.summary,
      priority: NotificationPriority.medium,
      isRead: false,
      isResolved: false,
      actionText: 'View Details',
    );

    context.read<HealthNotificationsBloc>().add(AddHealthNotification(testNotification));
  }
}

enum NotificationFilter {
  all,
  today,
  week,
  unread,
  resolved,
}
