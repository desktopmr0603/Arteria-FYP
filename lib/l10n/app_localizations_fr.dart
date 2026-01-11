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
  String get faqVoiceAIQuestion =>
      'Comment l\'application utilise-t-elle les commandes vocales et l\'IA ?';

  @override
  String get faqVoiceAIAnswer =>
      'Lorsque vous énoncez vos données de santé (par exemple, \"Ma tension est de 130 sur 80, et j\'ai pris mon Lisinopril\"), le moteur de synthèse vocale (STT) de l\'application transcrit les informations en toute sécurité. Ces données transcrites, y compris les lectures, les médicaments et les notes sur le mode de vie, sont transmises au LLM spécialisé Mistral 7B Instruct v0.3. Le LLM effectue un raisonnement clinique pour :\n\n• Identifier des modèles et des tendances subtils dans vos données.\n• Suggérer des corrélations potentielles entre vos actions (alimentation, exercice, stress) et vos lectures de tension artérielle.\n• Fournir des conseils raisonnés et exploitables directement adaptés à votre profil unique et à votre historique enregistré.';

  @override
  String get faqLoggingInfoQuestion =>
      'Quels types d\'informations puis-je enregistrer avec ma voix ?';

  @override
  String get faqLoggingInfoAnswer =>
      'Arteria prend en charge l\'enregistrement de toutes les mesures de santé critiques liées à votre profil cardiovasculaire :\n\n• Lectures de tension artérielle : Systolique, Diastolique et Pouls (Fréquence cardiaque).\n• Adhérence aux médicaments : Nom, dosage et heure de prise.\n• Facteurs de mode de vie : Alimentation, exercice, qualité du sommeil, niveaux de stress et symptômes spécifiques.';

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
  String get faqVoiceRecordingQuestion =>
      'L\'enregistrement vocal est-il sauvegardé ?';

  @override
  String get faqVoiceRecordingAnswer =>
      'L\'audio vocal brut est principalement utilisé pour la transcription immédiate via le moteur STT et n\'est pas stocké de manière permanente. La transcription textuelle résultante et les données de santé structurées qui en découlent sont enregistrées et conservées en toute sécurité pour alimenter les fonctionnalités de suivi longitudinal et de raisonnement du LLM.';

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
}
