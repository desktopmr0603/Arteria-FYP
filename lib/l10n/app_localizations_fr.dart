// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Arteria';

  @override
  String get welcomeBack => 'Bon retour!';

  @override
  String get loginSubtitle =>
      'Connectez-vous pour continuer à surveiller avec Arteria';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get emailRequired => 'L\'email est requis';

  @override
  String get passwordRequired => 'Le mot de passe est requis';

  @override
  String get forgotPassword => 'Mot de passe oublié?';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get enterEmail => 'Entrez votre email...';

  @override
  String get cancel => 'ANNULER';

  @override
  String get reset => 'RÉINITIALISER';

  @override
  String get login => 'Connexion';

  @override
  String get orContinueWith => 'Ou continuer avec';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte?';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get settings => 'Paramètres';

  @override
  String get home => 'Accueil';

  @override
  String get insights => 'Aperçus';

  @override
  String get history => 'Historique';

  @override
  String get more => 'Plus';

  @override
  String welcomeFirstTime(String name) {
    return 'Bienvenue, $name! 🎉';
  }

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get goodAfternoon => 'Bon après-midi';

  @override
  String get goodEvening => 'Bonsoir';

  @override
  String greetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get trackBPWithAI => 'Suivez votre tension artérielle avec l\'IA';

  @override
  String get noRecentReadings => 'Aucune lecture récente';

  @override
  String get criticalBP => 'TA critique - Veuillez consulter un médecin';

  @override
  String get bpHighToday => 'Votre TA est élevée aujourd\'hui';

  @override
  String get bpSlightlyElevated => 'Votre TA est légèrement élevée';

  @override
  String get bpElevated => 'Votre TA est légèrement au-dessus de la normale';

  @override
  String get bpNormalToday => 'Votre TA est normale aujourd\'hui ✓';

  @override
  String get recordNewReading => 'Enregistrer une nouvelle lecture';

  @override
  String get takeFirstReading => 'Prenez votre première lecture';

  @override
  String get viewTrends => 'Voir les tendances';

  @override
  String get reminders => 'Rappels';

  @override
  String get setUpReminders => 'Configurer les rappels';

  @override
  String get reminderSettings => 'Paramètres de rappel';

  @override
  String get reminderSettingsDescription =>
      'Configurez des rappels pour suivre régulièrement votre tension artérielle.';

  @override
  String get featureComingSoon =>
      'Cette fonctionnalité sera bientôt disponible!';

  @override
  String get gotIt => 'Compris';

  @override
  String get trendsPageComingSoon => 'Page des tendances bientôt disponible';

  @override
  String get aiInsightsComingSoon => 'Aperçus IA bientôt disponibles!';

  @override
  String get bpHistoryWillAppear => 'Votre historique de TA apparaîtra ici.';

  @override
  String get yourInfo => 'Vos informations';

  @override
  String get age => 'Âge';

  @override
  String get height => 'Taille';

  @override
  String get weight => 'Poids';

  @override
  String get gender => 'Genre';

  @override
  String get appHealthSettings => 'Paramètres de l\'application et de la santé';

  @override
  String get measurementHistoryExport =>
      'Historique et exportation des mesures';

  @override
  String get reminderSettingsMenu => 'Paramètres de rappel';

  @override
  String get securityPrivacy => 'Sécurité et confidentialité';

  @override
  String get appSettings => 'Paramètres de l\'application';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get language => 'Langue';

  @override
  String get faqHelpCenter => 'FAQ / Centre d\'aide';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get comingSoon => 'Bientôt disponible!';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get takeNextReading => 'Prenez votre prochaine lecture';

  @override
  String get tomorrowAt8AM => 'Demain à 8h00';

  @override
  String get latestReading => 'Dernière lecture';

  @override
  String get elevated => 'Élevée';

  @override
  String get high => 'Haute';

  @override
  String get critical => 'Critique';

  @override
  String get normal => 'Normale';

  @override
  String get nextSteps => 'Prochaines étapes';

  @override
  String get noPendingActions => 'Aucune action en attente';

  @override
  String get systolic => 'Systolique';

  @override
  String get diastolic => 'Diastolique';

  @override
  String get justNow => 'À l\'instant';

  @override
  String minutesAgo(int minutes) {
    return 'Il y a ${minutes}m';
  }

  @override
  String hoursAgo(int hours) {
    return 'Il y a ${hours}h';
  }

  @override
  String daysAgo(int days) {
    return 'Il y a ${days}j';
  }

  @override
  String get yesterday => 'Hier';

  @override
  String get youreAllSet => 'Vous êtes prêt!';

  @override
  String get firstTimeDescription =>
      'Enregistrez votre première mesure de tension artérielle pour commencer à suivre votre santé avec des informations basées sur l\'IA.';

  @override
  String get noDateRecorded => 'Aucune date enregistrée';

  @override
  String get faqTitle => 'FAQ et Centre d\'aide';

  @override
  String get faqAlertsQuestion =>
      'Quelles sont les fonctionnalités d\'alerte et de rappel ?';

  @override
  String get faqAlertsAnswer =>
      'Arteria fournit des outils proactifs essentiels pour l\'adhérence et la cohérence :\n\n• Rappels de mesure de la TA : Alertes configurables pour vous inviter à prendre vos lectures à des heures régulières (par exemple, matin et soir), fournissant l\'ensemble de données le plus précieux pour l\'analyse des tendances.\n• Rappels de médicaments : Alertes opportunes et fiables pour vous assurer de ne jamais manquer une dose, un facteur critique dans la gestion efficace de l\'hypertension.';

  @override
  String get faqDoctorReplacementQuestion =>
      'Arteria peut-elle remplacer mon médecin ou mon pharmacien ?';

  @override
  String get faqDoctorReplacementAnswer =>
      'Absolument pas. Arteria est uniquement un outil de surveillance et de soutien informatif. Les conseils et les informations générés par le LLM sont basés sur des connaissances cliniques établies et vos données autodéclarées, mais ils ne remplacent pas un diagnostic, un avis ou un traitement médical professionnel. Consultez toujours votre médecin ou votre professionnel de santé concernant tout problème de santé, tout changement de médicament ou avant d\'agir sur toute information fournie par l\'application.';

  @override
  String get faqShareDataQuestion =>
      'Comment puis-je partager les données d\'Arteria avec mon équipe soignante ?';

  @override
  String get faqShareDataAnswer =>
      'Arteria offre des fonctionnalités de rapport robustes. Vous pouvez générer des rapports complets et structurés (par exemple, fichiers PDF ou CSV) qui résument votre :\n\n• TA moyenne sur des périodes personnalisées.\n• Historique détaillé des lectures avec les étiquettes et notes correspondantes.\n• Journal d\'adhérence aux médicaments.\n\nCela permet un examen et une discussion efficaces lors de vos rendez-vous médicaux.';

  @override
  String get faqSecurityQuestion =>
      'Comment mes informations de santé personnelles sont-elles sécurisées dans Arteria ?';

  @override
  String get faqSecurityAnswer =>
      'Nous prenons la sécurité des données et la confidentialité des utilisateurs très au sérieux, en suivant les meilleures pratiques pour les applications de santé mobile :\n\n• Chiffrement en transit : Toutes les données transmises entre l\'application et nos serveurs sécurisés utilisent Transport Layer Security (TLS 1.2/1.3) pour un chiffrement de bout en bout.\n• Chiffrement au repos : Vos données sensibles sont stockées sur une infrastructure backend sécurisée et chiffrée.\n• Minimisation des données : Nous ne collectons et ne stockons que les données nécessaires aux fonctions principales de l\'application (suivi, analyse, génération de conseils).\n• Conformité : Nos systèmes sont conçus avec une architecture et des garanties pour répondre aux normes de protection des données pertinentes (par exemple, HIPAA, GDPR ou normes mondiales équivalentes).';

  @override
  String get faqDataTrainingQuestion =>
      'Mes données sont-elles utilisées pour entraîner le LLM ?';

  @override
  String get faqDataTrainingAnswer =>
      'Nous pouvons utiliser des données utilisateur anonymisées et agrégées pour améliorer continuellement la précision et la pertinence des capacités de raisonnement du modèle Mistral 7B. Vos informations personnelles d\'identification ne sont jamais utilisées à des fins de formation sans consentement explicite et éclairé.';

  @override
  String get bloodPressure => 'Tension Artérielle';

  @override
  String get recording => 'Enregistrement';

  @override
  String get tapToRecord => 'Appuyez pour enregistrer';

  @override
  String get tapToStop => 'Appuyez pour arrêter';

  @override
  String get tapMicrophoneToRecord =>
      'Appuyez sur le microphone pour enregistrer votre tension artérielle';

  @override
  String get recordingSpeakClearly =>
      'Enregistrement… Énoncez clairement votre tension artérielle.';

  @override
  String get transcribingVoice => 'Transcription de votre voix…';

  @override
  String get analyzingBP => 'Analyse de votre tension artérielle...';

  @override
  String get returningHome => 'Retour à l\'écran d\'accueil...';

  @override
  String get microphonePermissionDenied => 'Permission du microphone refusée';

  @override
  String get addReminder => 'Ajouter un rappel';

  @override
  String get editReminder => 'Modifier le rappel';

  @override
  String get saveReminder => 'Enregistrer le rappel';

  @override
  String get updateReminder => 'Mettre à jour le rappel';

  @override
  String get noRemindersYet => 'Aucun rappel pour l\'instant';

  @override
  String get noRemindersDescription =>
      'Configurez des rappels pour suivre régulièrement votre tension artérielle et maintenir de bonnes habitudes de santé.';

  @override
  String get reminderDeleted => 'Rappel supprimé';

  @override
  String get undo => 'Annuler';

  @override
  String get retry => 'Réessayer';

  @override
  String get repeat => 'Répéter';

  @override
  String get daily => 'Quotidien';

  @override
  String get weekdays => 'Jours de semaine';

  @override
  String get weekends => 'Week-ends';

  @override
  String get custom => 'Personnalisé';

  @override
  String get quickStatsBloodPressure => 'TENSION ARTÉRIELLE';

  @override
  String get quickStatsSystolic => 'SYSTOLIQUE';

  @override
  String get quickStatsDiastolic => 'DIASTOLIQUE';

  @override
  String get quickStatsLastRecorded => 'DERNIÈRE MESURE';

  @override
  String get quickStatsNoReadingsYet => 'Aucune lecture';

  @override
  String get statusHypertensiveCrisis => 'Crise hypertensive';

  @override
  String get statusStage2Hypertension => 'Hypertension stade 2';

  @override
  String get statusStage1Hypertension => 'Hypertension stade 1';

  @override
  String get statusElevated => 'Élevée';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusNormal => 'Normale';

  @override
  String minAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String hAgo(int hours) {
    return 'il y a ${hours}h';
  }

  @override
  String get medicationTodaysMedications => 'Médicaments du jour';

  @override
  String get medicationNoMedicationsAdded => 'Aucun médicament ajouté';

  @override
  String get medicationTapToAdd =>
      'Appuyez sur + pour ajouter votre premier médicament';

  @override
  String get medicationTaken => 'Pris';

  @override
  String medicationDueAt(String time) {
    return 'À prendre à $time';
  }

  @override
  String get medicationAsNeeded => 'Au besoin';

  @override
  String medicationNext(String time) {
    return 'Prochain : $time';
  }

  @override
  String get medicationCompletedForToday => 'Terminé pour aujourd\'hui';

  @override
  String get medicationAddMedication => 'Ajouter un médicament';

  @override
  String get medicationName => 'Nom du médicament';

  @override
  String get medicationDosage => 'Dosage';

  @override
  String get medicationFrequency => 'Fréquence';

  @override
  String get medicationTimes => 'Heures (séparées par des virgules)';

  @override
  String get medicationSave => 'Enregistrer le médicament';

  @override
  String medicationMoreMedications(int count) {
    return '+ $count autres médicaments';
  }

  @override
  String get frequencyOnceDaily => 'Une fois par jour';

  @override
  String get frequencyTwiceDaily => 'Deux fois par jour';

  @override
  String get frequencyThreeTimesDaily => 'Trois fois par jour';

  @override
  String get frequencyWeekly => 'Hebdomadaire';

  @override
  String get frequencyAsNeeded => 'Au besoin';

  @override
  String get emergencyHypertensiveCrisis => 'Crise hypertensive';

  @override
  String get emergencyHighBloodPressure => 'Tension artérielle élevée';

  @override
  String get emergencySeekImmediate => 'Consultez immédiatement un médecin';

  @override
  String get emergencyContactProvider => 'Contactez votre médecin';

  @override
  String get emergencyCall911 => 'Appeler le 15';

  @override
  String get emergencyCallContact => 'Appeler le contact';

  @override
  String get emergencyAddContact => 'Ajouter un contact d\'urgence';

  @override
  String get emergencyAddContactTitle => 'Ajouter un contact d\'urgence';

  @override
  String get emergencyContactNotified =>
      'Cette personne sera notifiée en cas d\'urgence';

  @override
  String get emergencyContactName => 'Nom du contact';

  @override
  String get emergencyPhoneNumber => 'Numéro de téléphone';

  @override
  String get emergencyRelationship => 'Relation';

  @override
  String get emergencySaveContact => 'Enregistrer le contact';

  @override
  String get familyCircle => 'Cercle familial';

  @override
  String familyConnected(int count) {
    return '$count connecté(s)';
  }

  @override
  String get familyInvite => 'Inviter';

  @override
  String get familyNoMembers => 'Aucun membre de la famille connecté';

  @override
  String get familyInviteDescription =>
      'Invitez la famille à partager vos données de santé';

  @override
  String get familyPermissionViewOnly => 'Lecture seule';

  @override
  String get familyPermissionViewExport => 'Lecture et exportation';

  @override
  String get familyPermissionFullAccess => 'Accès complet';

  @override
  String get familyInviteFamilyMember => 'Inviter un membre de la famille';

  @override
  String get familyShareHealthData =>
      'Partagez vos données de santé avec les membres de votre famille';

  @override
  String get familyEmailOptional => 'Email (facultatif)';

  @override
  String get familyPhoneOptional => 'Téléphone (facultatif)';

  @override
  String get familyPermissionLevel => 'Niveau d\'autorisation';

  @override
  String get familySendInvite => 'Envoyer l\'invitation';

  @override
  String get familyOrGenerateCode => 'Ou générez un code d\'invitation';

  @override
  String get familyGenerateInviteCode => 'Générer un code d\'invitation';

  @override
  String get familyInviteCode => 'Code d\'invitation';

  @override
  String get familyCopy => 'Copier';

  @override
  String get familyCodeCopied => 'Code copié dans le presse-papiers';

  @override
  String get familyShareCodeDescription =>
      'Partagez ce code avec les membres de votre famille';

  @override
  String get familyCanViewReadings => 'Peut voir vos lectures';

  @override
  String get familyCanViewShare => 'Peut voir et partager les rapports';

  @override
  String get familyFullAccessData => 'Accès complet à vos données';

  @override
  String familyInviteSent(String email) {
    return 'Invitation envoyée à $email';
  }

  @override
  String get familyEnterEmailOrPhone => 'Veuillez entrer un email ou téléphone';

  @override
  String get healthTipsTitle => 'Conseils santé';

  @override
  String get healthTipMeasureTime => 'Mesurez à la même heure';

  @override
  String get healthTipMeasureTimeDesc =>
      'Prenez votre tension artérielle à la même heure chaque jour pour des lectures cohérentes.';

  @override
  String get healthTipRestBefore => 'Reposez-vous avant de mesurer';

  @override
  String get healthTipRestBeforeDesc =>
      'Asseyez-vous tranquillement pendant 5 minutes avant de prendre votre lecture pour des résultats précis.';

  @override
  String get healthTipWatchDiet => 'Surveillez votre alimentation';

  @override
  String get healthTipWatchDietDesc =>
      'Réduisez la consommation de sodium et mangez plus de fruits, légumes et céréales complètes.';

  @override
  String get healthTipStayActive => 'Restez actif';

  @override
  String get healthTipStayActiveDesc =>
      'Visez 30 minutes d\'exercice modéré la plupart des jours de la semaine.';

  @override
  String get healthTipManageStress => 'Gérez le stress';

  @override
  String get healthTipManageStressDesc =>
      'Pratiquez des techniques de relaxation comme la respiration profonde ou la méditation.';

  @override
  String get healthTipLimitAlcohol => 'Limitez l\'alcool';

  @override
  String get healthTipLimitAlcoholDesc =>
      'Une consommation modérée d\'alcool peut aider à maintenir une tension artérielle saine.';

  @override
  String get healthTipDontSkipMeds => 'Ne sautez pas vos médicaments';

  @override
  String get healthTipDontSkipMedsDesc =>
      'Prenez vos médicaments comme prescrit, même lorsque vous vous sentez bien.';

  @override
  String get weeklyThisWeek => 'Cette semaine';

  @override
  String weeklyReadings(int count) {
    return '$count lectures';
  }

  @override
  String get trendsBloodPressure => 'Tension artérielle';

  @override
  String get trendsHistory => 'Historique';

  @override
  String get trendsTrendAnalysis => 'Analyse des tendances';

  @override
  String get trendsOverview => 'Aperçu';

  @override
  String get trendsReadings => 'Lectures';

  @override
  String get trendsSysAvg => 'Moy. SYS';

  @override
  String get trendsDiaAvg => 'Moy. DIA';

  @override
  String get trendsNoDataAvailable => 'Aucune donnée disponible';

  @override
  String get trendsRecentReadings => 'Lectures récentes';

  @override
  String get trendsBpGuide => 'Guide de classification TA';

  @override
  String get trendsBpNormal => 'Normale';

  @override
  String get trendsBpElevated => 'Élevée';

  @override
  String get trendsBpHighStage1 => 'Élevée stade 1';

  @override
  String get trendsBpHighStage2 => 'Élevée stade 2';

  @override
  String get trendsBpCrisis => 'Crise';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get healthDashboard => 'TABLEAU DE BORD SANTÉ';

  @override
  String get timeRangeLast7Days => '7 derniers jours';

  @override
  String get timeRangeLast30Days => '30 derniers jours';

  @override
  String get timeRangeLast90Days => '90 derniers jours';

  @override
  String get timeRangeThisYear => 'Cette année';

  @override
  String get timeRangeCustom => 'Période personnalisée';

  @override
  String get userDefault => 'Utilisateur';

  @override
  String get dialogSummaryForDoctor => 'Résumé pour le médecin';

  @override
  String get dialogTextReport => 'Rapport textuel';

  @override
  String get dialogClose => 'Fermer';

  @override
  String get trendsAvgBp => 'Pression artérielle moyenne';

  @override
  String trendsReadingsOver(int count, String range) {
    return '$count lectures sur $range';
  }

  @override
  String get trendsNoDataYet => 'Aucune donnée de tension artérielle';

  @override
  String get trendsStartRecording =>
      'Enregistrez vos mesures pour voir les tendances';

  @override
  String get trendsSystolic => 'Systolique';

  @override
  String get trendsDiastolic => 'Diastolique';

  @override
  String get whatIfSimulator => 'Simulateur de Scénarios';

  @override
  String get whatIfSimulatorDescription =>
      'Explorez comment les changements de mode de vie pourraient affecter votre tension artérielle. Il s\'agit d\'une simulation à des fins éducatives uniquement.';

  @override
  String get whatIfSimulatorCancel => 'Pas maintenant';

  @override
  String get whatIfSimulatorConfirm => 'Ouvrir le simulateur';

  @override
  String medicationAddedMessage(String name) {
    return '$name a été ajouté à vos médicaments.';
  }

  @override
  String get medicationAddError =>
      'Échec de l\'ajout du médicament. Veuillez réessayer.';

  @override
  String get prescriptionTitle => 'Nouvelle Prescription';

  @override
  String get viewOnHome => 'Voir le tableau de bord';

  @override
  String get medicationDosageLabel => 'Dosage';

  @override
  String get medicationFrequencyLabel => 'Fréquence';

  @override
  String get medicationInstructionsLabel => 'Instructions';

  @override
  String medicationAlreadyExists(Object name) {
    return '$name est déjà dans votre liste.';
  }
}
