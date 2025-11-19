import 'package:arteria/features/home/presentation/microphone_transcribe.dart';
import 'package:arteria/features/home/presentation/settings_screen.dart';
import 'package:arteria/features/user data/user_bloc.dart';
import 'package:arteria/features/user data/user_event.dart';
import 'package:arteria/features/user data/user_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    return WillPopScope(
      onWillPop: () async => false, // Disable system back button
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
            elevation: 0,
            centerTitle: true,
            title: _currentIndex == 3
                ? Text('Settings', style: theme.appBarTheme.titleTextStyle)
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: 'Insights',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                activeIcon: Icon(Icons.history_toggle_off),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz),
                label: 'More',
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
  static const Color _accentCoral = Color(0xFFFF6F61);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgCardColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF5F7FA);

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(state, theme),
              const SizedBox(height: 4),
              Text(
                'Track your blood pressure with AI',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 32),
              if (state is UserLoading) ...[
                _buildSkeletonCard(bgCardColor),
                const SizedBox(height: 40),
                _buildSkeletonButton(isDark),
              ] else if (state is UserLoaded && state.isFirstTimeUser) ...[
                _buildFirstTimeCard(bgCardColor, theme),
                const SizedBox(height: 40),
                _buildRecordButton(context),
              ] else ...[
                _buildReadingCard(bgCardColor, theme),
                const SizedBox(height: 40),
                _buildRecordButton(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreeting(UserState state, ThemeData theme) {
    final text = state is UserLoaded
        ? (state.isFirstTimeUser
              ? "Welcome, ${state.firstName}! 🎉"
              : "Hello, ${state.firstName}")
        : 'Welcome Back';

    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(fontSize: 34),
    );
  }

  Widget _buildFirstTimeCard(Color bgColor, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You're all set!",
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 12),
          Text(
            "Record your first blood pressure reading to begin tracking your health.",
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(Color bgColor, ThemeData theme) {
    DateTime? readingDate;
    final rawDate = latestReading?['date'];
    if (rawDate is DateTime) {
      readingDate = rawDate;
    } else if (rawDate is Timestamp) {
      readingDate = rawDate.toDate();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Latest Reading',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
              Icon(Icons.favorite, color: _accentCoral, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bpColumn(
                label: "Systolic",
                value: "${latestReading?['systolic'] ?? '--'}",
                theme: theme,
              ),
              Text(
                "/",
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 28),
              ),
              _bpColumn(
                label: "Diastolic",
                value: "${latestReading?['diastolic'] ?? '--'}",
                theme: theme,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            readingDate != null
                ? "Recorded on ${dateFormat.format(readingDate)}"
                : "No readings yet",
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  static Widget _bpColumn({
    required String label,
    required String value,
    required ThemeData theme,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 28)),
        Text("mmHg", style: theme.textTheme.bodySmall),
      ],
    );
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
        label: const Text(
          "Record New Reading",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildSkeletonCard(Color bgColor) => Container(
    height: 140,
    width: double.infinity,
    decoration: BoxDecoration(
      color: bgColor,
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
            "AI Insights coming soon!",
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
            "Your BP history will appear here.",
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
