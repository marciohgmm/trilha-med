import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/access/app_access_feature.dart';
import 'package:flutter_application_1/data/app_access_default_seed.dart';
import 'package:flutter_application_1/data/commercial_plan_presentation.dart';
import 'package:flutter_application_1/models/app_access_comparison_row_model.dart';
import 'package:flutter_application_1/models/app_access_config_model.dart';
import 'package:flutter_application_1/models/app_access_plan_tier_model.dart';

void main() {
  test('seed P0 inclui schemaVersion e enforcement desligado', () {
    final cfg = AppAccessDefaultSeed.defaults();
    expect(cfg.schemaVersion, 1);
    expect(cfg.accessEnforcementEnabled, isFalse);
    expect(cfg.free.limitFor(AppAccessFeature.flashcards), 50);
    expect(cfg.free.limitFor(AppAccessFeature.questions), 20);
  });

  test('comparação exibe texto de limite no gratuito', () {
    final cfg = AppAccessDefaultSeed.defaults();
    final rows = CommercialPlanPresentation.buildComparisonFromAccessConfig(cfg);
    final flashcards = rows.firstWhere(
      (r) => r.benefit == AppAccessFeature.flashcards.label,
    );
    expect(flashcards.freeText, 'Até 50');
    expect(flashcards.premiumText, 'Ilimitado');
  });

  test('limit=0 no gratuito gera Indisponível', () {
    final cfg = AppAccessConfigModel(
      free: const AppAccessPlanTierModel(
        enabledByField: {'questionsEnabled': true},
        limitsByField: {'questionsLimit': 0},
      ),
      premium: const AppAccessPlanTierModel(
        enabledByField: {'questionsEnabled': true},
      ),
    );
    final row = CommercialPlanPresentation.buildComparisonFromAccessConfig(cfg)
        .firstWhere((r) => r.benefit == AppAccessFeature.questions.label);
    expect(row.freeText, 'Indisponível');
  });

  test('override de comparisonRows substitui texto', () {
    final cfg = AppAccessConfigModel(
      free: AppAccessDefaultSeed.defaults().free,
      premium: AppAccessDefaultSeed.defaults().premium,
      comparisonRows: const [
        AppAccessComparisonRowModel(
          featureId: 'flashcards',
          freeText: '50 cards grátis',
          premiumText: 'Sem limite',
        ),
      ],
    );
    final row = CommercialPlanPresentation.buildComparisonFromAccessConfig(cfg)
        .firstWhere((r) => r.benefit == AppAccessFeature.flashcards.label);
    expect(row.freeText, '50 cards grátis');
    expect(row.premiumText, 'Sem limite');
  });
}
