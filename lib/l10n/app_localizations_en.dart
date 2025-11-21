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

  @override
  String get latestReading => 'Latest Reading';

  @override
  String get elevated => 'Elevated';

  @override
  String get high => 'High';

  @override
  String get critical => 'Critical';

  @override
  String get normal => 'Normal';

  @override
  String get nextSteps => 'Next Steps';

  @override
  String get noPendingActions => 'No pending actions';

  @override
  String get systolic => 'Systolic';

  @override
  String get diastolic => 'Diastolic';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get youreAllSet => 'You\'re all set!';

  @override
  String get firstTimeDescription =>
      'Record your first blood pressure reading to begin tracking your health journey with AI-powered insights.';

  @override
  String get noDateRecorded => 'No date recorded';

  @override
  String get faqTitle => 'FAQ & Help Center';

  @override
  String get faqVoiceAIQuestion =>
      'How does the app use voice commands and AI?';

  @override
  String get faqVoiceAIAnswer =>
      'When you speak your health data (e.g., \"My BP is 130 over 80, and I took my Lisinopril\"), the app\'s Speech-to-Text (STT) engine securely transcribes the information. This transcribed data, including readings, medications, and lifestyle notes, is fed to the specialized Mistral 7B Instruct v0.3 LLM. The LLM performs clinical reasoning to:\n\n• Identify subtle patterns and trends in your data.\n• Suggest potential correlations between your actions (diet, exercise, stress) and your blood pressure readings.\n• Provide reasoned, actionable advice directly tailored to your unique profile and recorded history.';

  @override
  String get faqLoggingInfoQuestion =>
      'What types of information can I log using my voice?';

  @override
  String get faqLoggingInfoAnswer =>
      'Arteria supports logging all critical health metrics related to your cardiovascular profile:\n\n• Blood Pressure Readings: Systolic, Diastolic, and Pulse (Heart Rate).\n• Medication Adherence: Name, dosage, and time taken.\n• Lifestyle Factors: Diet, exercise, sleep quality, stress levels, and specific symptoms.';

  @override
  String get faqAlertsQuestion => 'What are the alert and reminder features?';

  @override
  String get faqAlertsAnswer =>
      'Arteria provides essential proactive tools for adherence and consistency:\n\n• BP Measurement Reminders: Configurable alerts to prompt you to take your readings at consistent times (e.g., morning and evening), providing the most valuable data set for trend analysis.\n• Medication Reminders: Timely, reliable alerts to ensure you never miss a dose, a critical factor in effective hypertension management.';

  @override
  String get faqDoctorReplacementQuestion =>
      'Can Arteria replace my doctor or pharmacist?';

  @override
  String get faqDoctorReplacementAnswer =>
      'Absolutely not. Arteria is a monitoring and informational support tool only. The advice and insights generated by the LLM are based on established clinical knowledge and your self-reported data, but they are not a substitute for professional medical diagnosis, advice, or treatment. Always consult your physician or healthcare provider regarding any health concerns, changes to your medication, or before acting on any information provided by the app.';

  @override
  String get faqShareDataQuestion =>
      'How can I share the data from Arteria with my healthcare team?';

  @override
  String get faqShareDataAnswer =>
      'Arteria offers robust reporting features. You can generate comprehensive, structured reports (e.g., PDF or CSV files) that summarize your:\n\n• Average BP over custom timeframes.\n• Detailed history of readings with corresponding tags and notes.\n• Medication adherence log.\n\nThis allows for efficient review and discussion during your medical appointments.';

  @override
  String get faqSecurityQuestion =>
      'How is my personal health information secured in Arteria?';

  @override
  String get faqSecurityAnswer =>
      'We take data security and user privacy extremely seriously, following best practices for mobile health applications:\n\n• Encryption In Transit: All data transmitted between the app and our secure servers uses Transport Layer Security (TLS 1.2/1.3) for end-to-end encryption.\n• Encryption At Rest: Your sensitive data is stored on secure, encrypted backend infrastructure.\n• Data Minimization: We only collect and store the necessary data required for the app\'s core functions (tracking, analysis, advice generation).\n• Compliance: Our systems are designed with architecture and safeguards to meet relevant data protection standards (e.g., HIPAA, GDPR, or equivalent global standards).';

  @override
  String get faqVoiceRecordingQuestion => 'Is the voice recording saved?';

  @override
  String get faqVoiceRecordingAnswer =>
      'The raw voice audio is primarily used for immediate transcription via the STT engine and is not permanently stored. The resulting text transcription and the structured health data derived from it are securely logged and retained to power the longitudinal tracking and LLM reasoning features.';

  @override
  String get faqDataTrainingQuestion => 'Is my data used to train the LLM?';

  @override
  String get faqDataTrainingAnswer =>
      'We may use anonymized and aggregated user data to continuously improve the accuracy and relevance of the Mistral 7B model\'s reasoning capabilities. Your personal identifying information is never used for training purposes without explicit, informed consent.';
}
