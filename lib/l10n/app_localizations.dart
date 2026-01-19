import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Arteria'**
  String get appTitle;

  /// Login page welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// Login page subtitle
  ///
  /// In en, this message translates to:
  /// **'Log in to continue monitoring with Arteria'**
  String get loginSubtitle;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Email validation error
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Password validation error
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Forgot password button text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Forgot password dialog title
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// Email input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your email...'**
  String get enterEmail;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// Reset button text
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get reset;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Divider text for alternative login methods
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// Google sign-in button text
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Sign up prompt text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Sign up link text
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Insights navigation label
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// History navigation label
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// More navigation label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// First time user welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}! 🎉'**
  String welcomeFirstTime(String name);

  /// Morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// Evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// Greeting with user's name
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String greetingWithName(String greeting, String name);

  /// Subtitle for first-time users
  ///
  /// In en, this message translates to:
  /// **'Track your blood pressure with AI'**
  String get trackBPWithAI;

  /// Message when no BP readings exist
  ///
  /// In en, this message translates to:
  /// **'No recent readings'**
  String get noRecentReadings;

  /// Critical blood pressure warning
  ///
  /// In en, this message translates to:
  /// **'Critical BP - Please consult a doctor'**
  String get criticalBP;

  /// High blood pressure message
  ///
  /// In en, this message translates to:
  /// **'Your BP is high today'**
  String get bpHighToday;

  /// Stage 1 hypertension blood pressure message
  ///
  /// In en, this message translates to:
  /// **'Your BP is slightly elevated'**
  String get bpSlightlyElevated;

  /// Elevated blood pressure message (systolic 121-129)
  ///
  /// In en, this message translates to:
  /// **'Your BP is slightly above normal'**
  String get bpElevated;

  /// Normal blood pressure message
  ///
  /// In en, this message translates to:
  /// **'Your BP is normal today'**
  String get bpNormalToday;

  /// Button to record new BP reading
  ///
  /// In en, this message translates to:
  /// **'Record New Reading'**
  String get recordNewReading;

  /// Button for new users to take their first BP reading
  ///
  /// In en, this message translates to:
  /// **'Take Your First Reading'**
  String get takeFirstReading;

  /// Button to view BP trends
  ///
  /// In en, this message translates to:
  /// **'View Trends'**
  String get viewTrends;

  /// Reminders button text
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// Set up reminders button text
  ///
  /// In en, this message translates to:
  /// **'Set Up Reminders'**
  String get setUpReminders;

  /// Reminder settings dialog title
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get reminderSettings;

  /// Reminder settings description
  ///
  /// In en, this message translates to:
  /// **'Set up reminders to track your blood pressure regularly.'**
  String get reminderSettingsDescription;

  /// Coming soon message
  ///
  /// In en, this message translates to:
  /// **'This feature will be available soon!'**
  String get featureComingSoon;

  /// Acknowledgment button text
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// Trends page coming soon message
  ///
  /// In en, this message translates to:
  /// **'Trends page coming soon'**
  String get trendsPageComingSoon;

  /// AI insights coming soon message
  ///
  /// In en, this message translates to:
  /// **'AI Insights coming soon!'**
  String get aiInsightsComingSoon;

  /// Empty history page message
  ///
  /// In en, this message translates to:
  /// **'Your BP history will appear here.'**
  String get bpHistoryWillAppear;

  /// User info section title
  ///
  /// In en, this message translates to:
  /// **'Your Info'**
  String get yourInfo;

  /// Age label
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// Height label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// Weight label
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// Gender label
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// App and health settings section title
  ///
  /// In en, this message translates to:
  /// **'App & Health Settings'**
  String get appHealthSettings;

  /// Measurement history menu item
  ///
  /// In en, this message translates to:
  /// **'Measurement History & Export'**
  String get measurementHistoryExport;

  /// Reminder settings menu item
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get reminderSettingsMenu;

  /// Security and privacy menu item
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get securityPrivacy;

  /// App settings section title
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// Dark mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Language menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// FAQ/Help center menu item
  ///
  /// In en, this message translates to:
  /// **'FAQ / Help Center'**
  String get faqHelpCenter;

  /// Log out button text
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Generic coming soon message
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get comingSoon;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// French language option
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// Next step reminder text
  ///
  /// In en, this message translates to:
  /// **'Take your next reading'**
  String get takeNextReading;

  /// Example reminder time
  ///
  /// In en, this message translates to:
  /// **'Tomorrow at 8:00 AM'**
  String get tomorrowAt8AM;

  /// BP card title for latest reading
  ///
  /// In en, this message translates to:
  /// **'Latest Reading'**
  String get latestReading;

  /// BP status label for elevated blood pressure
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get elevated;

  /// BP status label for high blood pressure
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// BP status label for critical blood pressure
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// BP status label for normal blood pressure
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// Next steps card title
  ///
  /// In en, this message translates to:
  /// **'Next Steps'**
  String get nextSteps;

  /// Message when no next steps are available
  ///
  /// In en, this message translates to:
  /// **'No pending actions'**
  String get noPendingActions;

  /// Systolic blood pressure label
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get systolic;

  /// Diastolic blood pressure label
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get diastolic;

  /// Time format for very recent readings
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Time format for readings from minutes ago
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// Time format for readings from hours ago
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// Time format for readings from days ago
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// Time format for yesterday's readings
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// First time user welcome title
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get youreAllSet;

  /// First time user description text
  ///
  /// In en, this message translates to:
  /// **'Record your first blood pressure reading to begin tracking your health journey with AI-powered insights.'**
  String get firstTimeDescription;

  /// Message when reading has no date
  ///
  /// In en, this message translates to:
  /// **'No date recorded'**
  String get noDateRecorded;

  /// Title for the FAQ screen
  ///
  /// In en, this message translates to:
  /// **'FAQ & Help Center'**
  String get faqTitle;

  /// FAQ Question about Alerts
  ///
  /// In en, this message translates to:
  /// **'What are the alert and reminder features?'**
  String get faqAlertsQuestion;

  /// FAQ Answer about Alerts
  ///
  /// In en, this message translates to:
  /// **'Arteria provides essential proactive tools for adherence and consistency:\n\n• BP Measurement Reminders: Configurable alerts to prompt you to take your readings at consistent times (e.g., morning and evening), providing the most valuable data set for trend analysis.\n• Medication Reminders: Timely, reliable alerts to ensure you never miss a dose, a critical factor in effective hypertension management.'**
  String get faqAlertsAnswer;

  /// FAQ Question about Doctor Replacement
  ///
  /// In en, this message translates to:
  /// **'Can Arteria replace my doctor or pharmacist?'**
  String get faqDoctorReplacementQuestion;

  /// FAQ Answer about Doctor Replacement
  ///
  /// In en, this message translates to:
  /// **'Absolutely not. Arteria is a monitoring and informational support tool only. The advice and insights generated by the LLM are based on established clinical knowledge and your self-reported data, but they are not a substitute for professional medical diagnosis, advice, or treatment. Always consult your physician or healthcare provider regarding any health concerns, changes to your medication, or before acting on any information provided by the app.'**
  String get faqDoctorReplacementAnswer;

  /// FAQ Question about Sharing Data
  ///
  /// In en, this message translates to:
  /// **'How can I share the data from Arteria with my healthcare team?'**
  String get faqShareDataQuestion;

  /// FAQ Answer about Sharing Data
  ///
  /// In en, this message translates to:
  /// **'Arteria offers robust reporting features. You can generate comprehensive, structured reports (e.g., PDF or CSV files) that summarize your:\n\n• Average BP over custom timeframes.\n• Detailed history of readings with corresponding tags and notes.\n• Medication adherence log.\n\nThis allows for efficient review and discussion during your medical appointments.'**
  String get faqShareDataAnswer;

  /// FAQ Question about Security
  ///
  /// In en, this message translates to:
  /// **'How is my personal health information secured in Arteria?'**
  String get faqSecurityQuestion;

  /// FAQ Answer about Security
  ///
  /// In en, this message translates to:
  /// **'We take data security and user privacy extremely seriously, following best practices for mobile health applications:\n\n• Encryption In Transit: All data transmitted between the app and our secure servers uses Transport Layer Security (TLS 1.2/1.3) for end-to-end encryption.\n• Encryption At Rest: Your sensitive data is stored on secure, encrypted backend infrastructure.\n• Data Minimization: We only collect and store the necessary data required for the app\'s core functions (tracking, analysis, advice generation).\n• Compliance: Our systems are designed with architecture and safeguards to meet relevant data protection standards (e.g., HIPAA, GDPR, or equivalent global standards).'**
  String get faqSecurityAnswer;

  /// FAQ Question about Data Training
  ///
  /// In en, this message translates to:
  /// **'Is my data used to train the LLM?'**
  String get faqDataTrainingQuestion;

  /// FAQ Answer about Data Training
  ///
  /// In en, this message translates to:
  /// **'We may use anonymized and aggregated user data to continuously improve the accuracy and relevance of the Mistral 7B model\'s reasoning capabilities. Your personal identifying information is never used for training purposes without explicit, informed consent.'**
  String get faqDataTrainingAnswer;

  /// Blood Pressure title
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get bloodPressure;

  /// Recording indicator text
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// Instruction to tap microphone
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get tapToRecord;

  /// Instruction to stop recording
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get tapToStop;

  /// Initial instruction on microphone screen
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone to record your blood pressure'**
  String get tapMicrophoneToRecord;

  /// Recording state instruction
  ///
  /// In en, this message translates to:
  /// **'Recording… Speak your blood pressure clearly.'**
  String get recordingSpeakClearly;

  /// Transcription state text
  ///
  /// In en, this message translates to:
  /// **'Transcribing your voice…'**
  String get transcribingVoice;

  /// Analysis state text
  ///
  /// In en, this message translates to:
  /// **'Analyzing your blood pressure...'**
  String get analyzingBP;

  /// Saving state text
  ///
  /// In en, this message translates to:
  /// **'Returning to homescreen...'**
  String get returningHome;

  /// Error when microphone permission is denied
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get microphonePermissionDenied;

  /// Add reminder button and dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Reminder'**
  String get addReminder;

  /// Edit reminder dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Reminder'**
  String get editReminder;

  /// Save reminder button text
  ///
  /// In en, this message translates to:
  /// **'Save Reminder'**
  String get saveReminder;

  /// Update reminder button text
  ///
  /// In en, this message translates to:
  /// **'Update Reminder'**
  String get updateReminder;

  /// Empty state title when no reminders
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get noRemindersYet;

  /// Empty state description for reminders
  ///
  /// In en, this message translates to:
  /// **'Set up reminders to track your blood pressure regularly and maintain healthy habits.'**
  String get noRemindersDescription;

  /// Snackbar message when reminder is deleted
  ///
  /// In en, this message translates to:
  /// **'Reminder deleted'**
  String get reminderDeleted;

  /// Undo action button text
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Repeat label for reminder frequency
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// Daily repeat option
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// Weekdays repeat option
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// Weekends repeat option
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// Custom repeat option
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @quickStatsBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'BLOOD PRESSURE'**
  String get quickStatsBloodPressure;

  /// No description provided for @quickStatsSystolic.
  ///
  /// In en, this message translates to:
  /// **'SYSTOLIC'**
  String get quickStatsSystolic;

  /// No description provided for @quickStatsDiastolic.
  ///
  /// In en, this message translates to:
  /// **'DIASTOLIC'**
  String get quickStatsDiastolic;

  /// No description provided for @quickStatsLastRecorded.
  ///
  /// In en, this message translates to:
  /// **'LAST RECORDED'**
  String get quickStatsLastRecorded;

  /// No description provided for @quickStatsNoReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get quickStatsNoReadingsYet;

  /// No description provided for @statusHypertensiveCrisis.
  ///
  /// In en, this message translates to:
  /// **'Hypertensive Crisis'**
  String get statusHypertensiveCrisis;

  /// No description provided for @statusStage2Hypertension.
  ///
  /// In en, this message translates to:
  /// **'Stage 2 Hypertension'**
  String get statusStage2Hypertension;

  /// No description provided for @statusStage1Hypertension.
  ///
  /// In en, this message translates to:
  /// **'Stage 1 Hypertension'**
  String get statusStage1Hypertension;

  /// No description provided for @statusElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get statusElevated;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get statusNormal;

  /// No description provided for @minAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minAgo(int minutes);

  /// No description provided for @hAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hAgo(int hours);

  /// No description provided for @medicationTodaysMedications.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Medications'**
  String get medicationTodaysMedications;

  /// No description provided for @medicationNoMedicationsAdded.
  ///
  /// In en, this message translates to:
  /// **'No medications added'**
  String get medicationNoMedicationsAdded;

  /// No description provided for @medicationTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first medication'**
  String get medicationTapToAdd;

  /// No description provided for @medicationTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get medicationTaken;

  /// No description provided for @medicationDueAt.
  ///
  /// In en, this message translates to:
  /// **'Due at {time}'**
  String medicationDueAt(String time);

  /// No description provided for @medicationAsNeeded.
  ///
  /// In en, this message translates to:
  /// **'As needed'**
  String get medicationAsNeeded;

  /// No description provided for @medicationNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String medicationNext(String time);

  /// No description provided for @medicationCompletedForToday.
  ///
  /// In en, this message translates to:
  /// **'Completed for today'**
  String get medicationCompletedForToday;

  /// No description provided for @medicationAddMedication.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get medicationAddMedication;

  /// No description provided for @medicationName.
  ///
  /// In en, this message translates to:
  /// **'Medication Name'**
  String get medicationName;

  /// No description provided for @medicationDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medicationDosage;

  /// No description provided for @medicationFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get medicationFrequency;

  /// No description provided for @medicationTimes.
  ///
  /// In en, this message translates to:
  /// **'Times (comma separated)'**
  String get medicationTimes;

  /// No description provided for @medicationSave.
  ///
  /// In en, this message translates to:
  /// **'Save Medication'**
  String get medicationSave;

  /// No description provided for @medicationMoreMedications.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more medications'**
  String medicationMoreMedications(int count);

  /// No description provided for @frequencyOnceDaily.
  ///
  /// In en, this message translates to:
  /// **'Once daily'**
  String get frequencyOnceDaily;

  /// No description provided for @frequencyTwiceDaily.
  ///
  /// In en, this message translates to:
  /// **'Twice daily'**
  String get frequencyTwiceDaily;

  /// No description provided for @frequencyThreeTimesDaily.
  ///
  /// In en, this message translates to:
  /// **'Three times daily'**
  String get frequencyThreeTimesDaily;

  /// No description provided for @frequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequencyWeekly;

  /// No description provided for @frequencyAsNeeded.
  ///
  /// In en, this message translates to:
  /// **'As needed'**
  String get frequencyAsNeeded;

  /// No description provided for @emergencyHypertensiveCrisis.
  ///
  /// In en, this message translates to:
  /// **'Hypertensive Crisis'**
  String get emergencyHypertensiveCrisis;

  /// No description provided for @emergencyHighBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'High Blood Pressure'**
  String get emergencyHighBloodPressure;

  /// No description provided for @emergencySeekImmediate.
  ///
  /// In en, this message translates to:
  /// **'Seek immediate medical care'**
  String get emergencySeekImmediate;

  /// No description provided for @emergencyContactProvider.
  ///
  /// In en, this message translates to:
  /// **'Contact your healthcare provider'**
  String get emergencyContactProvider;

  /// No description provided for @emergencyCall911.
  ///
  /// In en, this message translates to:
  /// **'Call 911'**
  String get emergencyCall911;

  /// No description provided for @emergencyCallContact.
  ///
  /// In en, this message translates to:
  /// **'Call Contact'**
  String get emergencyCallContact;

  /// No description provided for @emergencyAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add Emergency Contact'**
  String get emergencyAddContact;

  /// No description provided for @emergencyAddContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Emergency Contact'**
  String get emergencyAddContactTitle;

  /// No description provided for @emergencyContactNotified.
  ///
  /// In en, this message translates to:
  /// **'This person will be notified in case of emergency'**
  String get emergencyContactNotified;

  /// No description provided for @emergencyContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get emergencyContactName;

  /// No description provided for @emergencyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get emergencyPhoneNumber;

  /// No description provided for @emergencyRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get emergencyRelationship;

  /// No description provided for @emergencySaveContact.
  ///
  /// In en, this message translates to:
  /// **'Save Contact'**
  String get emergencySaveContact;

  /// No description provided for @familyCircle.
  ///
  /// In en, this message translates to:
  /// **'Family Circle'**
  String get familyCircle;

  /// No description provided for @familyConnected.
  ///
  /// In en, this message translates to:
  /// **'{count} connected'**
  String familyConnected(int count);

  /// No description provided for @familyInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get familyInvite;

  /// No description provided for @familyNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No family members connected'**
  String get familyNoMembers;

  /// No description provided for @familyInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Invite family to share your health data'**
  String get familyInviteDescription;

  /// No description provided for @familyPermissionViewOnly.
  ///
  /// In en, this message translates to:
  /// **'View Only'**
  String get familyPermissionViewOnly;

  /// No description provided for @familyPermissionViewExport.
  ///
  /// In en, this message translates to:
  /// **'View & Export'**
  String get familyPermissionViewExport;

  /// No description provided for @familyPermissionFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full Access'**
  String get familyPermissionFullAccess;

  /// No description provided for @familyInviteFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Family Member'**
  String get familyInviteFamilyMember;

  /// No description provided for @familyShareHealthData.
  ///
  /// In en, this message translates to:
  /// **'Share your health data with family members'**
  String get familyShareHealthData;

  /// No description provided for @familyEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get familyEmailOptional;

  /// No description provided for @familyPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get familyPhoneOptional;

  /// No description provided for @familyPermissionLevel.
  ///
  /// In en, this message translates to:
  /// **'Permission Level'**
  String get familyPermissionLevel;

  /// No description provided for @familySendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send Invite'**
  String get familySendInvite;

  /// No description provided for @familyOrGenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Or generate an invite code'**
  String get familyOrGenerateCode;

  /// No description provided for @familyGenerateInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Code'**
  String get familyGenerateInviteCode;

  /// No description provided for @familyInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get familyInviteCode;

  /// No description provided for @familyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get familyCopy;

  /// No description provided for @familyCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get familyCodeCopied;

  /// No description provided for @familyShareCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Share this code with family members'**
  String get familyShareCodeDescription;

  /// No description provided for @familyCanViewReadings.
  ///
  /// In en, this message translates to:
  /// **'Can view your readings'**
  String get familyCanViewReadings;

  /// No description provided for @familyCanViewShare.
  ///
  /// In en, this message translates to:
  /// **'Can view and share reports'**
  String get familyCanViewShare;

  /// No description provided for @familyFullAccessData.
  ///
  /// In en, this message translates to:
  /// **'Full access to your data'**
  String get familyFullAccessData;

  /// No description provided for @familyInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {email}'**
  String familyInviteSent(String email);

  /// No description provided for @familyEnterEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter email or phone'**
  String get familyEnterEmailOrPhone;

  /// No description provided for @healthTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Tips'**
  String get healthTipsTitle;

  /// No description provided for @healthTipMeasureTime.
  ///
  /// In en, this message translates to:
  /// **'Measure at the Same Time'**
  String get healthTipMeasureTime;

  /// No description provided for @healthTipMeasureTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Take your blood pressure at the same time each day for consistent readings.'**
  String get healthTipMeasureTimeDesc;

  /// No description provided for @healthTipRestBefore.
  ///
  /// In en, this message translates to:
  /// **'Rest Before Measuring'**
  String get healthTipRestBefore;

  /// No description provided for @healthTipRestBeforeDesc.
  ///
  /// In en, this message translates to:
  /// **'Sit quietly for 5 minutes before taking your reading for accurate results.'**
  String get healthTipRestBeforeDesc;

  /// No description provided for @healthTipWatchDiet.
  ///
  /// In en, this message translates to:
  /// **'Watch Your Diet'**
  String get healthTipWatchDiet;

  /// No description provided for @healthTipWatchDietDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce sodium intake and eat more fruits, vegetables, and whole grains.'**
  String get healthTipWatchDietDesc;

  /// No description provided for @healthTipStayActive.
  ///
  /// In en, this message translates to:
  /// **'Stay Active'**
  String get healthTipStayActive;

  /// No description provided for @healthTipStayActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Aim for 30 minutes of moderate exercise most days of the week.'**
  String get healthTipStayActiveDesc;

  /// No description provided for @healthTipManageStress.
  ///
  /// In en, this message translates to:
  /// **'Manage Stress'**
  String get healthTipManageStress;

  /// No description provided for @healthTipManageStressDesc.
  ///
  /// In en, this message translates to:
  /// **'Practice relaxation techniques like deep breathing or meditation.'**
  String get healthTipManageStressDesc;

  /// No description provided for @healthTipLimitAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Limit Alcohol'**
  String get healthTipLimitAlcohol;

  /// No description provided for @healthTipLimitAlcoholDesc.
  ///
  /// In en, this message translates to:
  /// **'Moderate alcohol consumption can help maintain healthy blood pressure.'**
  String get healthTipLimitAlcoholDesc;

  /// No description provided for @healthTipDontSkipMeds.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Skip Medications'**
  String get healthTipDontSkipMeds;

  /// No description provided for @healthTipDontSkipMedsDesc.
  ///
  /// In en, this message translates to:
  /// **'Take your medications as prescribed, even when you feel well.'**
  String get healthTipDontSkipMedsDesc;

  /// No description provided for @weeklyThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get weeklyThisWeek;

  /// No description provided for @weeklyReadings.
  ///
  /// In en, this message translates to:
  /// **'{count} readings'**
  String weeklyReadings(int count);

  /// No description provided for @trendsBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get trendsBloodPressure;

  /// No description provided for @trendsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get trendsHistory;

  /// No description provided for @trendsTrendAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Trend Analysis'**
  String get trendsTrendAnalysis;

  /// No description provided for @trendsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get trendsOverview;

  /// No description provided for @trendsReadings.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get trendsReadings;

  /// No description provided for @trendsSysAvg.
  ///
  /// In en, this message translates to:
  /// **'SYS Avg'**
  String get trendsSysAvg;

  /// No description provided for @trendsDiaAvg.
  ///
  /// In en, this message translates to:
  /// **'DIA Avg'**
  String get trendsDiaAvg;

  /// No description provided for @trendsNoDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get trendsNoDataAvailable;

  /// No description provided for @trendsRecentReadings.
  ///
  /// In en, this message translates to:
  /// **'Recent Readings'**
  String get trendsRecentReadings;

  /// No description provided for @trendsBpGuide.
  ///
  /// In en, this message translates to:
  /// **'BP Classification Guide'**
  String get trendsBpGuide;

  /// No description provided for @trendsBpNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get trendsBpNormal;

  /// No description provided for @trendsBpElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get trendsBpElevated;

  /// No description provided for @trendsBpHighStage1.
  ///
  /// In en, this message translates to:
  /// **'High Stage 1'**
  String get trendsBpHighStage1;

  /// No description provided for @trendsBpHighStage2.
  ///
  /// In en, this message translates to:
  /// **'High Stage 2'**
  String get trendsBpHighStage2;

  /// No description provided for @trendsBpCrisis.
  ///
  /// In en, this message translates to:
  /// **'Crisis'**
  String get trendsBpCrisis;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @healthDashboard.
  ///
  /// In en, this message translates to:
  /// **'HEALTH DASHBOARD'**
  String get healthDashboard;

  /// No description provided for @timeRangeLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get timeRangeLast7Days;

  /// No description provided for @timeRangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get timeRangeLast30Days;

  /// No description provided for @timeRangeLast90Days.
  ///
  /// In en, this message translates to:
  /// **'Last 90 Days'**
  String get timeRangeLast90Days;

  /// No description provided for @timeRangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get timeRangeThisYear;

  /// No description provided for @timeRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get timeRangeCustom;

  /// No description provided for @userDefault.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userDefault;

  /// No description provided for @dialogSummaryForDoctor.
  ///
  /// In en, this message translates to:
  /// **'Summary for Doctor'**
  String get dialogSummaryForDoctor;

  /// No description provided for @dialogTextReport.
  ///
  /// In en, this message translates to:
  /// **'Text Report'**
  String get dialogTextReport;

  /// No description provided for @dialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get dialogClose;

  /// No description provided for @trendsAvgBp.
  ///
  /// In en, this message translates to:
  /// **'Average Blood Pressure'**
  String get trendsAvgBp;

  /// No description provided for @trendsReadingsOver.
  ///
  /// In en, this message translates to:
  /// **'{count} readings over {range}'**
  String trendsReadingsOver(int count, String range);

  /// No description provided for @trendsNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No blood pressure data yet'**
  String get trendsNoDataYet;

  /// No description provided for @trendsStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording your readings to see trends'**
  String get trendsStartRecording;

  /// No description provided for @trendsSystolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get trendsSystolic;

  /// No description provided for @trendsDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get trendsDiastolic;

  /// Title for the What-If confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'What-If Simulator'**
  String get whatIfSimulator;

  /// Description for the What-If confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Explore how lifestyle changes could impact your blood pressure. This is a simulation for educational purposes only.'**
  String get whatIfSimulatorDescription;

  /// Cancel button for the What-If confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get whatIfSimulatorCancel;

  /// Confirm button for the What-If confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Open Simulator'**
  String get whatIfSimulatorConfirm;

  /// Success message when a medication is added via AI
  ///
  /// In en, this message translates to:
  /// **'{name} has been added to your medications.'**
  String medicationAddedMessage(String name);

  /// No description provided for @medicationAddError.
  ///
  /// In en, this message translates to:
  /// **'Failed to add medication. Please try again.'**
  String get medicationAddError;

  /// No description provided for @prescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Prescription'**
  String get prescriptionTitle;

  /// No description provided for @viewOnHome.
  ///
  /// In en, this message translates to:
  /// **'View on Dashboard'**
  String get viewOnHome;

  /// No description provided for @medicationDosageLabel.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medicationDosageLabel;

  /// No description provided for @medicationFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get medicationFrequencyLabel;

  /// No description provided for @medicationInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get medicationInstructionsLabel;

  /// No description provided for @medicationAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'{name} is already in your list.'**
  String medicationAlreadyExists(Object name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
