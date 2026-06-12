import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/access/app_access_feature.dart';
import 'package:flutter_application_1/data/app_access_default_seed.dart';
import 'package:flutter_application_1/data/commercial_plan_catalog.dart';
import 'package:flutter_application_1/models/app_access_plan_tier_model.dart';
import 'package:flutter_application_1/models/app_access_config_model.dart';

void main() {
  test('tabela do admin: ferramentas médicas só no gratuito', () {
    final cfg = AppAccessDefaultSeed.defaults();
    expect(cfg.free.isFeatureEnabled(AppAccessFeature.medicalTools), isTrue);
    expect(cfg.premium.isFeatureEnabled(AppAccessFeature.medicalTools), isFalse);

    final rows = CommercialPlanCatalog.comparisonForDisplay(accessConfig: cfg);
    final medical = rows.firstWhere(
      (r) => r.benefit == AppAccessFeature.medicalTools.label,
    );
    expect(medical.includedInFree, isTrue);
    expect(medical.includedInPremium, isFalse);
  });

  test('Premium herda benefício do Gratuito quando ambos ligados', () {
    final cfg = AppAccessConfigModel(
      free: const AppAccessPlanTierModel(
        enabledByField: {'flashcardsEnabled': true},
      ),
      premium: const AppAccessPlanTierModel(
        enabledByField: {'flashcardsEnabled': true},
      ),
    );
    final row = CommercialPlanCatalog.comparisonForDisplay(accessConfig: cfg)
        .firstWhere((r) => r.benefit == AppAccessFeature.flashcards.label);
    expect(row.includedInFree, isTrue);
    expect(row.includedInPremium, isTrue);
  });

  test('admin pode marcar simulados só no premium', () {
    final cfg = AppAccessConfigModel(
      free: const AppAccessPlanTierModel(
        enabledByField: {'simulatorsEnabled': false},
      ),
      premium: const AppAccessPlanTierModel(
        enabledByField: {'simulatorsEnabled': true},
      ),
    );
    final row = CommercialPlanCatalog.comparisonForDisplay(accessConfig: cfg)
        .firstWhere((r) => r.benefit == AppAccessFeature.simulators.label);
    expect(row.includedInFree, isFalse);
    expect(row.includedInPremium, isTrue);
  });
}
