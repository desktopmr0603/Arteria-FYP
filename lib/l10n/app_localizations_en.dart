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
    return 'Welcome, $name!';
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
  String get bpElevated => 'Your BP is slightly above normal';

  @override
  String get bpNormalToday => 'Your BP is normal today';

  @override
  String get recordNewReading => 'Record New Reading';

  @override
  String get takeFirstReading => 'Take Your First Reading';

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
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordMessage =>
      'A password reset link will be sent to your email address.';

  @override
  String get passwordResetSent => 'Password reset email sent!';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmationMessage =>
      'Are you sure you want to permanently delete your account? This action cannot be undone.';

  @override
  String get accountDeleted => 'Account deleted successfully.';

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
  String get faqDataTrainingQuestion => 'Is my data used to train the LLM?';

  @override
  String get faqDataTrainingAnswer =>
      'We may use anonymized and aggregated user data to continuously improve the accuracy and relevance of the Qwen3 8b model\'s reasoning capabilities. Your personal identifying information is never used for training purposes without explicit, informed consent.';

  @override
  String get bloodPressure => 'Blood Pressure';

  @override
  String get recording => 'Recording';

  @override
  String get tapToRecord => 'Tap to record';

  @override
  String get tapToStop => 'Tap to stop';

  @override
  String get tapMicrophoneToRecord =>
      'Tap the microphone to record your blood pressure';

  @override
  String get recordingSpeakClearly =>
      'Recording… Speak your blood pressure clearly.';

  @override
  String get transcribingVoice => 'Transcribing your voice…';

  @override
  String get analyzingBP => 'Analyzing your blood pressure...';

  @override
  String get returningHome => 'Returning to homescreen...';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied';

  @override
  String get addReminder => 'Add Reminder';

  @override
  String get editReminder => 'Edit Reminder';

  @override
  String get saveReminder => 'Save Reminder';

  @override
  String get updateReminder => 'Update Reminder';

  @override
  String get noRemindersYet => 'No reminders yet';

  @override
  String get noRemindersDescription =>
      'Set up reminders to track your blood pressure regularly and maintain healthy habits.';

  @override
  String get reminderDeleted => 'Reminder deleted';

  @override
  String get undo => 'Undo';

  @override
  String get retry => 'Retry';

  @override
  String get repeat => 'Repeat';

  @override
  String get daily => 'Daily';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get custom => 'Custom';

  @override
  String get quickStatsBloodPressure => 'BLOOD PRESSURE';

  @override
  String get quickStatsSystolic => 'SYSTOLIC';

  @override
  String get quickStatsDiastolic => 'DIASTOLIC';

  @override
  String get quickStatsLastRecorded => 'LAST RECORDED';

  @override
  String get quickStatsNoReadingsYet => 'No readings yet';

  @override
  String get statusHypertensiveCrisis => 'Hypertensive Crisis';

  @override
  String get statusStage2Hypertension => 'Stage 2 Hypertension';

  @override
  String get statusStage1Hypertension => 'Stage 1 Hypertension';

  @override
  String get statusElevated => 'Elevated';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusNormal => 'Normal';

  @override
  String minAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String get medicationTodaysMedications => 'Today\'s Medications';

  @override
  String get medicationNoMedicationsAdded => 'No medications added';

  @override
  String get medicationTapToAdd => 'Tap + to add your first medication';

  @override
  String get medicationTaken => 'Taken';

  @override
  String medicationDueAt(String time) {
    return 'Due at $time';
  }

  @override
  String get medicationAsNeeded => 'As needed';

  @override
  String medicationNext(String time) {
    return 'Next: $time';
  }

  @override
  String get medicationCompletedForToday => 'Completed for today';

  @override
  String get medicationAddMedication => 'Add Medication';

  @override
  String get medicationName => 'Medication Name';

  @override
  String get medicationDosage => 'Dosage';

  @override
  String get medicationFrequency => 'Frequency';

  @override
  String get medicationTimes => 'Times (comma separated)';

  @override
  String get medicationSave => 'Save Medication';

  @override
  String medicationMoreMedications(int count) {
    return '+ $count more medications';
  }

  @override
  String get frequencyOnceDaily => 'Once daily';

  @override
  String get frequencyTwiceDaily => 'Twice daily';

  @override
  String get frequencyThreeTimesDaily => 'Three times daily';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyAsNeeded => 'As needed';

  @override
  String get emergencyHypertensiveCrisis => 'Hypertensive Crisis';

  @override
  String get emergencyHighBloodPressure => 'High Blood Pressure';

  @override
  String get emergencySeekImmediate => 'Seek immediate medical care';

  @override
  String get emergencyContactProvider => 'Contact your healthcare provider';

  @override
  String get emergencyCall911 => 'Call 114';

  @override
  String get emergencyCallContact => 'Call Contact';

  @override
  String get emergencyAddContact => 'Add Emergency Contact';

  @override
  String get emergencyAddContactTitle => 'Add Emergency Contact';

  @override
  String get emergencyContactNotified =>
      'This person will be notified in case of emergency';

  @override
  String get emergencyContactName => 'Contact Name';

  @override
  String get emergencyPhoneNumber => 'Phone Number';

  @override
  String get emergencyRelationship => 'Relationship';

  @override
  String get emergencySaveContact => 'Save Contact';

  @override
  String get familyCircle => 'Family Circle';

  @override
  String familyConnected(int count) {
    return '$count connected';
  }

  @override
  String get familyInvite => 'Invite';

  @override
  String get familyNoMembers => 'No family members connected';

  @override
  String get familyInviteDescription =>
      'Invite family to share your health data';

  @override
  String get familyPermissionViewOnly => 'View Only';

  @override
  String get familyPermissionViewExport => 'View & Export';

  @override
  String get familyPermissionFullAccess => 'Full Access';

  @override
  String get familyInviteFamilyMember => 'Invite Family Member';

  @override
  String get familyShareHealthData =>
      'Share your health data with family members';

  @override
  String get familyEmailOptional => 'Email (optional)';

  @override
  String get familyPhoneOptional => 'Phone (optional)';

  @override
  String get familyPermissionLevel => 'Permission Level';

  @override
  String get familySendInvite => 'Send Invite';

  @override
  String get familyOrGenerateCode => 'Or generate an invite code';

  @override
  String get familyGenerateInviteCode => 'Generate Invite Code';

  @override
  String get familyInviteCode => 'Invite Code';

  @override
  String get familyCopy => 'Copy';

  @override
  String get familyCodeCopied => 'Code copied to clipboard';

  @override
  String get familyShareCodeDescription =>
      'Share this code with family members';

  @override
  String get familyCanViewReadings => 'Can view your readings';

  @override
  String get familyCanViewShare => 'Can view and share reports';

  @override
  String get familyFullAccessData => 'Full access to your data';

  @override
  String familyInviteSent(String email) {
    return 'Invite sent to $email';
  }

  @override
  String get familyEnterEmailOrPhone => 'Please enter email or phone';

  @override
  String get healthTipsTitle => 'Health Tips';

  @override
  String get healthTipMeasureTime => 'Measure at the Same Time';

  @override
  String get healthTipMeasureTimeDesc =>
      'Take your blood pressure at the same time each day for consistent readings.';

  @override
  String get healthTipRestBefore => 'Rest Before Measuring';

  @override
  String get healthTipRestBeforeDesc =>
      'Sit quietly for 5 minutes before taking your reading for accurate results.';

  @override
  String get healthTipWatchDiet => 'Watch Your Diet';

  @override
  String get healthTipWatchDietDesc =>
      'Reduce sodium intake and eat more fruits, vegetables, and whole grains.';

  @override
  String get healthTipStayActive => 'Stay Active';

  @override
  String get healthTipStayActiveDesc =>
      'Aim for 30 minutes of moderate exercise most days of the week.';

  @override
  String get healthTipManageStress => 'Manage Stress';

  @override
  String get healthTipManageStressDesc =>
      'Practice relaxation techniques like deep breathing or meditation.';

  @override
  String get healthTipLimitAlcohol => 'Limit Alcohol';

  @override
  String get healthTipLimitAlcoholDesc =>
      'Moderate alcohol consumption can help maintain healthy blood pressure.';

  @override
  String get healthTipDontSkipMeds => 'Don\'t Skip Medications';

  @override
  String get healthTipDontSkipMedsDesc =>
      'Take your medications as prescribed, even when you feel well.';

  @override
  String get weeklyThisWeek => 'This Week';

  @override
  String weeklyReadings(int count) {
    return '$count readings';
  }

  @override
  String get trendsBloodPressure => 'Blood Pressure';

  @override
  String get trendsHistory => 'History';

  @override
  String get trendsTrendAnalysis => 'Trend Analysis';

  @override
  String get trendsOverview => 'Overview';

  @override
  String get trendsReadings => 'Readings';

  @override
  String get trendsSysAvg => 'SYS Avg';

  @override
  String get trendsDiaAvg => 'DIA Avg';

  @override
  String get trendsNoDataAvailable => 'No data available';

  @override
  String get trendsRecentReadings => 'Recent Readings';

  @override
  String get trendsBpGuide => 'BP Classification Guide';

  @override
  String get trendsBpNormal => 'Normal';

  @override
  String get trendsBpElevated => 'Elevated';

  @override
  String get trendsBpHighStage1 => 'High Stage 1';

  @override
  String get trendsBpHighStage2 => 'High Stage 2';

  @override
  String get trendsBpCrisis => 'Crisis';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get healthDashboard => 'HEALTH DASHBOARD';

  @override
  String get timeRangeLast7Days => 'Last 7 Days';

  @override
  String get timeRangeLast30Days => 'Last 30 Days';

  @override
  String get timeRangeLast90Days => 'Last 90 Days';

  @override
  String get timeRangeThisYear => 'This Year';

  @override
  String get timeRangeCustom => 'Custom Range';

  @override
  String get userDefault => 'User';

  @override
  String get dialogSummaryForDoctor => 'Summary for Doctor';

  @override
  String get dialogTextReport => 'Text Report';

  @override
  String get dialogClose => 'Close';

  @override
  String get trendsAvgBp => 'Average Blood Pressure';

  @override
  String trendsReadingsOver(int count, String range) {
    return '$count readings over $range';
  }

  @override
  String get trendsNoDataYet => 'No blood pressure data yet';

  @override
  String get trendsStartRecording =>
      'Start recording your readings to see trends';

  @override
  String get trendsSystolic => 'Systolic';

  @override
  String get trendsDiastolic => 'Diastolic';

  @override
  String get whatIfSimulator => 'What-If Simulator';

  @override
  String get whatIfSimulatorDescription =>
      'Explore how lifestyle changes could impact your blood pressure. This is a simulation for educational purposes only.';

  @override
  String get whatIfSimulatorCancel => 'Not Now';

  @override
  String get whatIfSimulatorConfirm => 'Open Simulator';

  @override
  String get predictiveTimelineTitle => 'Predictive Health Timeline';

  @override
  String get predictiveTimelineSubtitle =>
      'AI-powered 30-day health projections';

  @override
  String get predictiveTimelineAnalyzing => 'Analyzing health patterns...';

  @override
  String get predictiveTimelineDay => 'Day';

  @override
  String get predictiveTimelineRisk => 'Risk';

  @override
  String get predictiveTimelineConfidence => 'Confidence';

  @override
  String get predictiveTimelineKeyInsights => 'Key Insights';

  @override
  String get predictiveTimelineRiskProjection => 'Risk Projection';

  @override
  String get predictiveTimelineOver30Days => 'over 30 days';

  @override
  String get predictiveTimelineConfidenceLevel => 'Confidence Level';

  @override
  String get predictiveTimelineKeyFactors => 'Key Factors';

  @override
  String get predictiveTimelineFactorBPTrend => 'BP Trend';

  @override
  String get predictiveTimelineFactorLifestyle => 'Lifestyle';

  @override
  String get predictiveTimelineFactorStress => 'Stress';

  @override
  String get predictiveTimelineFactorMedication => 'Medication';

  @override
  String get riskTrendAnalysisTitle => 'Risk Trend Analysis';

  @override
  String get riskTrendAnalysisSubtitle =>
      '90-day historical analysis with feature impact';

  @override
  String get riskTrendAnalysisAnalyzing => 'Analyzing risk patterns...';

  @override
  String get riskTrendAnalysisFeatureImpact => 'Feature Impact Analysis';

  @override
  String get riskTrendAnalysisSummary => 'Risk Summary';

  @override
  String get riskTrendAnalysisCurrentRisk => 'Current Risk';

  @override
  String get riskTrendAnalysisWeeklyChange => 'Weekly Change';

  @override
  String get riskTrendAnalysisMonthlyChange => 'Monthly Change';

  @override
  String get riskTrendAnalysisLowRisk => 'Low Risk';

  @override
  String get riskTrendAnalysisModerateRisk => 'Moderate Risk';

  @override
  String get riskTrendAnalysisElevatedRisk => 'Elevated Risk';

  @override
  String get riskTrendAnalysisHighRisk => 'High Risk';

  @override
  String get riskTrendAnalysisVeryHighRisk => 'Very High Risk';

  @override
  String get historicalPatternsTitle => 'Historical Patterns';

  @override
  String get historicalPatternsSubtitle =>
      'AI-detected patterns and anomalies from your health data';

  @override
  String get historicalPatternsAnalyzing => 'Analyzing historical patterns...';

  @override
  String get historicalPatternsPositivePatterns => 'Positive Patterns';

  @override
  String get historicalPatternsNeedsAttention => 'Needs Attention';

  @override
  String get historicalPatternsRecentAnomalies => 'Recent Anomalies';

  @override
  String get historicalPatternsDetectedPatterns => 'Detected Patterns';

  @override
  String get historicalPatternsDaily => 'Daily';

  @override
  String get historicalPatternsWeekly => 'Weekly';

  @override
  String get historicalPatternsVariable => 'Variable';

  @override
  String get historicalPatternsPositive => 'Positive';

  @override
  String get historicalPatternsModerate => 'Moderate';

  @override
  String get historicalPatternsHigh => 'High';

  @override
  String get historicalPatternsOccurrences => 'occurrences';

  @override
  String get historicalPatternsResolved => 'Resolved';

  @override
  String get historicalPatternsToday => 'Today';

  @override
  String get historicalPatternsYesterday => 'Yesterday';

  @override
  String historicalPatternsDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get patternMorningSpikeTitle => 'Morning Blood Pressure Spike';

  @override
  String patternMorningSpikeDescription(Object diff) {
    return 'Your morning systolic readings run about $diff mmHg higher than the rest of the day.';
  }

  @override
  String get patternMorningSpikeRecommendation =>
      'Try measuring after 5 minutes seated. If this keeps happening, discuss timing of medication, sleep, and caffeine with your doctor.';

  @override
  String get patternWeekendReliefTitle => 'Weekend Stress Relief';

  @override
  String patternWeekendReliefDescription(Object diff) {
    return 'Your systolic readings are about $diff mmHg lower on weekends compared to weekdays.';
  }

  @override
  String get patternWeekendReliefRecommendation =>
      'Whatever you do on weekends (sleep, walking, less stress) seems to help — try bringing one of those habits into weekdays.';

  @override
  String get patternHighVariabilityTitle => 'High Variability';

  @override
  String patternHighVariabilityDescription(Object diff) {
    return 'Your readings vary quite a bit (about $diff mmHg typical swing).';
  }

  @override
  String get patternHighVariabilityRecommendation =>
      'Try to measure at consistent times each day, avoid measuring right after activity/caffeine, and record notes (stress, sleep, meals).';

  @override
  String anomalyDeviationHigh(Object value) {
    return 'Reading is $value mmHg higher than usual.';
  }

  @override
  String anomalyDeviationLow(Object value) {
    return 'Reading is $value mmHg lower than usual.';
  }

  @override
  String anomalySpikeIncrease(Object value) {
    return 'Sudden increase of $value mmHg from previous.';
  }

  @override
  String anomalySpikeDecrease(Object value) {
    return 'Sudden decrease of $value mmHg from previous.';
  }

  @override
  String get anomalyResolved => 'Resolved';

  @override
  String medicationAddedMessage(String name) {
    return '$name added successfully.';
  }

  @override
  String get medicationAddError =>
      'Failed to add medication. Please try again.';

  @override
  String get prescriptionTitle => 'New Prescription';

  @override
  String get viewOnHome => 'View on Dashboard';

  @override
  String get medicationDosageLabel => 'Dosage';

  @override
  String get medicationFrequencyLabel => 'Frequency';

  @override
  String get medicationInstructionsLabel => 'Instructions';

  @override
  String medicationAlreadyExists(String name) {
    return '$name is already in your list.';
  }

  @override
  String get logoutConfirmationMessage => 'Are you sure you want to log out?';

  @override
  String get loggingOut => 'Logging out...';

  @override
  String remindersSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders set',
      one: '1 reminder set',
    );
    return '$_temp0';
  }

  @override
  String get statusConnecting => 'Connecting...';

  @override
  String get statusTapToSpeak => 'Tap to speak';

  @override
  String get statusListening => 'Listening...';

  @override
  String get statusDetectingSilence => 'Detecting silence...';

  @override
  String get statusProcessing => 'Processing...';

  @override
  String get statusTranscribing => 'Transcribing...';

  @override
  String get statusThinking => 'Thinking...';

  @override
  String get statusResponseReceived => 'Response received';

  @override
  String get statusSpeaking => 'Speaking...';

  @override
  String get statusConnectionError => 'Connection error';

  @override
  String get statusErrorProcessingAudio => 'Error processing audio';

  @override
  String get statusClarificationNeeded => 'Clarification needed';

  @override
  String get statusGeneratingReport => 'Generating report...';

  @override
  String get statusErrorGeneratingReport => 'Error generating report';

  @override
  String get statusUnderstandingQuery => 'Understanding your health query...';

  @override
  String get bpCategoryNormal => 'Normal';

  @override
  String get bpCategoryElevated => 'Elevated';

  @override
  String get bpCategoryStage1 => 'Stage 1 Hypertension';

  @override
  String get bpCategoryStage2 => 'Stage 2 Hypertension';

  @override
  String get bpCategoryCrisis => 'Hypertensive Crisis';

  @override
  String get insightsPageTitle => 'Health Assistant';

  @override
  String get insightsHeroPrompt => 'How are you feeling today?';
}
