import 'package:arteria/features/home/presentation/components/bp_reading_card.dart';
import 'package:arteria/features/home/presentation/components/next_steps_card.dart';
import 'package:arteria/features/home/presentation/microphone_transcribe.dart';
import 'package:arteria/features/home/presentation/settings_screen.dart';
import 'package:arteria/features/user data/user_bloc.dart';
import 'package:arteria/features/user data/user_event.dart';
import 'package:arteria/features/user data/user_state.dart';
import 'package:arteria/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  Map<String, dynamic>? _latestReading;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static const Color _primaryBlue = Color(0xFF1976D2);

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserData());
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> pages = [
      HomepageContent(latestReading: _latestReading, dateFormat: _dateFormat),
      const InsightsPage(),
      const HistoryPage(),
      const SettingsScreen(),
    ];

    return PopScope<Object?>(
      canPop: false,
      child: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserLoaded) {
            setState(() => _latestReading = state.latestReading);
          } else if (state is UserError && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false, // Remove back button
            backgroundColor: theme.appBarTheme.backgroundColor,
            scrolledUnderElevation: 0.0,
            elevation: 0,
            centerTitle: true,
            title: _currentIndex == 3
                ? Text(
                    AppLocalizations.of(context)!.settings,
                    style: theme.appBarTheme.titleTextStyle,
                  )
                : const Text(
                    'Arteria',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _primaryBlue,
                    ),
                  ),
          ),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor:
                theme.bottomNavigationBarTheme.unselectedItemColor,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: AppLocalizations.of(context)!.home,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.insights_outlined),
                activeIcon: const Icon(Icons.insights),
                label: AppLocalizations.of(context)!.insights,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history),
                activeIcon: const Icon(Icons.history_toggle_off),
                label: AppLocalizations.of(context)!.history,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.more_horiz),
                label: AppLocalizations.of(context)!.more,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomepageContent extends StatelessWidget {
  final Map<String, dynamic>? latestReading;
  final DateFormat dateFormat;

  const HomepageContent({
    super.key,
    required this.latestReading,
    required this.dateFormat,
  });

  static const Color _primaryBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting section
              _buildGreeting(context, state, theme, isDark),
              const SizedBox(height: 32),

              // Loading state
              if (state is UserLoading) ...[
                _buildSkeletonCard(),
                const SizedBox(height: 24),
                _buildSkeletonButton(isDark),
              ]
              // First time user
              else if (state is UserLoaded && state.isFirstTimeUser) ...[
                BPReadingCard(isFirstTime: true),
                const SizedBox(height: 24),
                _buildRecordButton(context),
                const SizedBox(height: 16),
                _buildReminderButton(context, theme),
              ]
              // Regular user with data
              else if (state is UserLoaded) ...[
                // Latest BP Reading Card
                BPReadingCard(
                  systolic: latestReading?['systolic'],
                  diastolic: latestReading?['diastolic'],
                  readingDate: _extractDate(latestReading?['date']),
                  category: _getCategory(
                    latestReading?['systolic'],
                    latestReading?['diastolic'],
                  ),
                ),
                const SizedBox(height: 24),

                // Next Steps Card
                NextStepsCard(steps: _getNextSteps(context, state)),
                const SizedBox(height: 32),

                // Primary Action Button
                _buildRecordButton(context),
                const SizedBox(height: 16),

                // Action Buttons Row
                _buildActionButtons(context, theme),
              ] else ...[
                // Error or other states
                _buildRecordButton(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreeting(
    BuildContext context,
    UserState state,
    ThemeData theme,
    bool isDark,
  ) {
    final firstName = state is UserLoaded
        ? _capitalizeFirstLetter(state.firstName)
        : '';

    final greeting = state is UserLoaded
        ? (state.isFirstTimeUser
              ? AppLocalizations.of(context)!.welcomeFirstTime(firstName)
              : AppLocalizations.of(
                  context,
                )!.greetingWithName(_getGreetingByTime(context), firstName))
        : AppLocalizations.of(context)!.welcomeBack;

    final statusText = state is UserLoaded && !state.isFirstTimeUser
        ? _getBPStatusMessage(
            context,
            latestReading?['systolic'],
            latestReading?['diastolic'],
          )
        : AppLocalizations.of(context)!.trackBPWithAI;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          statusText,
          style: GoogleFonts.openSans(
            fontSize: 15,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _getGreetingByTime(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLocalizations.of(context)!.goodMorning;
    } else if (hour < 17) {
      return AppLocalizations.of(context)!.goodAfternoon;
    } else {
      return AppLocalizations.of(context)!.goodEvening;
    }
  }

  String _getBPStatusMessage(
    BuildContext context,
    int? systolic,
    int? diastolic,
  ) {
    if (systolic == null || diastolic == null) {
      return AppLocalizations.of(context)!.noRecentReadings;
    }

    if (systolic >= 180 || diastolic >= 120) {
      return AppLocalizations.of(context)!.criticalBP;
    } else if (systolic >= 140 || diastolic >= 90) {
      return AppLocalizations.of(context)!.bpHighToday;
    } else if (systolic >= 130 || diastolic >= 80) {
      return AppLocalizations.of(context)!.bpSlightlyElevated;
    } else {
      return AppLocalizations.of(context)!.bpNormalToday;
    }
  }

  Widget _buildRecordButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push<Map<String, dynamic>?>(
            context,
            MaterialPageRoute(builder: (_) => const MicrophoneTranscribe()),
          );
          if (result != null && context.mounted) {
            context.read<UserBloc>().add(
              SaveBPReading(
                systolic: result["systolic"],
                diastolic: result["diastolic"],
              ),
            );
          }
        },
        icon: const Icon(Icons.mic),
        label: Text(
          AppLocalizations.of(context)!.recordNewReading,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  DateTime? _extractDate(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    return null;
  }

  String _getCategory(int? systolic, int? diastolic) {
    if (systolic == null || diastolic == null) return 'normal';
    if (systolic >= 180 || diastolic >= 120) return 'critical';
    if (systolic >= 140 || diastolic >= 90) return 'high';
    if (systolic >= 130 || diastolic >= 80) return 'elevated';
    return 'normal';
  }

  List<NextStepItem> _getNextSteps(BuildContext context, UserLoaded state) {
    // TODO: Generate dynamic reminders based on user schedule and medication
    final nextSteps = <NextStepItem>[];

    // Example: Add reading reminder
    nextSteps.add(
      NextStepItem(
        title: AppLocalizations.of(context)!.takeNextReading,
        time: AppLocalizations.of(context)!.tomorrowAt8AM,
        color: const Color(0xFF1976D2),
      ),
    );

    return nextSteps;
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to History/Trends page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.trendsPageComingSoon,
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.show_chart, size: 22),
            label: Text(
              AppLocalizations.of(context)!.viewTrends,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _openReminderSettings(context);
            },
            icon: const Icon(Icons.notifications_outlined, size: 22),
            label: Text(
              AppLocalizations.of(context)!.reminders,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderButton(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _openReminderSettings(context);
        },
        icon: const Icon(Icons.notifications_outlined, size: 20),
        label: Text(
          AppLocalizations.of(context)!.setUpReminders,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _openReminderSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF1976D2)),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.reminderSettings,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.reminderSettingsDescription,
              style: GoogleFonts.openSans(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.featureComingSoon,
              style: GoogleFonts.openSans(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.gotIt,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1976D2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() => Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(20),
    ),
  );

  Widget _buildSkeletonButton(bool isDark) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insights, size: 64, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.aiInsightsComingSoon,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.bpHistoryWillAppear,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
