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

  /// Elevated blood pressure message
  ///
  /// In en, this message translates to:
  /// **'Your BP is slightly elevated'**
  String get bpSlightlyElevated;

  /// Normal blood pressure message
  ///
  /// In en, this message translates to:
  /// **'Your BP is normal today ✓'**
  String get bpNormalToday;

  /// Button to record new BP reading
  ///
  /// In en, this message translates to:
  /// **'Record New Reading'**
  String get recordNewReading;

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
