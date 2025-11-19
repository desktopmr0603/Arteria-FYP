// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Arteria';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get loginSubtitle => 'Log in to continue monitoring with Arteria';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get enterEmail => 'Enter your email...';

  @override
  String get cancel => 'CANCEL';

  @override
  String get reset => 'RESET';

  @override
  String get login => 'Login';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get settings => 'Settings';

  @override
  String get home => 'Home';

  @override
  String get insights => 'Insights';

  @override
  String get history => 'History';

  @override
  String get more => 'More';

  @override
  String welcomeFirstTime(String name) {
    return 'Welcome, $name! 🎉';
  }

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String greetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get trackBPWithAI => 'Track your blood pressure with AI';

  @override
  String get noRecentReadings => 'No recent readings';

  @override
  String get criticalBP => 'Critical BP - Please consult a doctor';

  @override
  String get bpHighToday => 'Your BP is high today';

  @override
  String get bpSlightlyElevated => 'Your BP is slightly elevated';

  @override
  String get bpNormalToday => 'Your BP is normal today ✓';

  @override
  String get recordNewReading => 'Record New Reading';

  @override
  String get viewTrends => 'View Trends';

  @override
  String get reminders => 'Reminders';

  @override
  String get setUpReminders => 'Set Up Reminders';

  @override
  String get reminderSettings => 'Reminder Settings';

  @override
  String get reminderSettingsDescription =>
      'Set up reminders to track your blood pressure regularly.';

  @override
  String get featureComingSoon => 'This feature will be available soon!';

  @override
  String get gotIt => 'Got it';

  @override
  String get trendsPageComingSoon => 'Trends page coming soon';

  @override
  String get aiInsightsComingSoon => 'AI Insights coming soon!';

  @override
  String get bpHistoryWillAppear => 'Your BP history will appear here.';

  @override
  String get yourInfo => 'Your Info';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get gender => 'Gender';

  @override
  String get appHealthSettings => 'App & Health Settings';

  @override
  String get measurementHistoryExport => 'Measurement History & Export';

  @override
  String get reminderSettingsMenu => 'Reminder Settings';

  @override
  String get securityPrivacy => 'Security & Privacy';

  @override
  String get appSettings => 'App Settings';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get faqHelpCenter => 'FAQ / Help Center';

  @override
  String get logOut => 'Log Out';

  @override
  String get comingSoon => 'Coming soon!';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get takeNextReading => 'Take your next reading';

  @override
  String get tomorrowAt8AM => 'Tomorrow at 8:00 AM';
}
