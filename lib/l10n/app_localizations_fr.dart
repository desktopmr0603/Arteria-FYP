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
}
