import '../core/access/app_access_feature.dart';
import '../models/app_access_config_model.dart';
import '../models/app_access_plan_tier_model.dart';

/// Valores padrão quando o documento ainda não existe no Firestore.
class AppAccessDefaultSeed {
  AppAccessDefaultSeed._();

  static AppAccessConfigModel defaults() {
    return AppAccessConfigModel(
      schemaVersion: 1,
      free: AppAccessPlanTierModel(
        enabledByField: {
          AppAccessFeature.flashcards.enabledField: true,
          AppAccessFeature.questions.enabledField: true,
          AppAccessFeature.simulators.enabledField: false,
          AppAccessFeature.medicalTools.enabledField: true,
          AppAccessFeature.smartReview.enabledField: false,
          AppAccessFeature.themes.enabledField: true,
          AppAccessFeature.practicalPhase.enabledField: false,
          AppAccessFeature.revalidaOfficial.enabledField: false,
        },
        limitsByField: {
          'flashcardsLimit': 50,
          'questionsLimit': 20,
          'themesLimit': 5,
          'medicalToolsLimit': 3,
        },
      ),
      premium: AppAccessPlanTierModel(
        enabledByField: {
          for (final f in AppAccessFeature.adminFeatures)
            f.enabledField: f != AppAccessFeature.medicalTools,
        },
        limitsByField: {
          'flashcardsLimit': 0,
          'questionsLimit': 0,
          'themesLimit': 0,
          'medicalToolsLimit': 0,
        },
      ),
      accessEnforcementEnabled: false,
      showLockedWithPadlock: true,
      showUpgradeButton: true,
    );
  }
}
