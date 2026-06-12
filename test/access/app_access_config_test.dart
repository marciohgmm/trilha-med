import 'package:flutter_application_1/core/access/app_access_feature.dart';
import 'package:flutter_application_1/core/commercial/commercial_entitlement.dart';
import 'package:flutter_application_1/data/app_access_default_seed.dart';
import 'package:flutter_application_1/domain/platform/models/commercial_access_snapshot.dart';
import 'package:flutter_application_1/application/access/app_access_service.dart';
import 'package:flutter_application_1/services/access/app_access_config_service.dart';
import 'package:flutter_application_1/models/app_access_plan_tier_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults — gratuito com flashcards e questões', () {
    final cfg = AppAccessDefaultSeed.defaults();
    expect(cfg.free.isFeatureEnabled(AppAccessFeature.flashcards), isTrue);
    expect(cfg.free.isFeatureEnabled(AppAccessFeature.simulators), isFalse);
    expect(cfg.premium.isFeatureEnabled(AppAccessFeature.simulators), isTrue);
  });

  test('evaluate — premium libera simulados', () {
    final cfg = AppAccessDefaultSeed.defaults();
    final service = AppAccessService(
      configService: AppAccessConfigService.memory(cfg),
    );
    final snap = CommercialAccessSnapshot(
      userId: 'u1',
      activeKeys: {CommercialEntitlementKey.premium},
    );
    final decision = service.evaluate(
      snap: snap,
      config: cfg,
      feature: AppAccessFeature.simulators,
    );
    expect(decision.allowed, isTrue);
    expect(decision.isPremiumUser, isTrue);
  });

  test('evaluate — gratuito bloqueia simulados', () {
    final cfg = AppAccessDefaultSeed.defaults();
    final service = AppAccessService(
      configService: AppAccessConfigService.memory(cfg),
    );
    final snap = CommercialAccessSnapshot.free('u2');
    final decision = service.evaluate(
      snap: snap,
      config: cfg,
      feature: AppAccessFeature.simulators,
    );
    expect(decision.allowed, isFalse);
    expect(decision.blockedByFeatureDisabled, isTrue);
  });

  test('evaluate — limite gratuito de questões', () {
    final cfg = AppAccessDefaultSeed.defaults().copyWith(
      free: AppAccessPlanTierModel(
        enabledByField: {
          AppAccessFeature.questions.enabledField: true,
        },
        limitsByField: {'questionsLimit': 10},
      ),
    );
    final service = AppAccessService(
      configService: AppAccessConfigService.memory(cfg),
    );
    final snap = CommercialAccessSnapshot.free('u3');
    expect(
      service.evaluate(
        snap: snap,
        config: cfg,
        feature: AppAccessFeature.questions,
        currentUsage: 9,
      ).allowed,
      isTrue,
    );
    expect(
      service.evaluate(
        snap: snap,
        config: cfg,
        feature: AppAccessFeature.questions,
        currentUsage: 10,
      ).blockedByLimit,
      isTrue,
    );
  });

  test('tier fromMap roundtrip', () {
    final tier = AppAccessPlanTierModel.fromMap({
      'flashcardsEnabled': true,
      'flashcardsLimit': 25,
    });
    expect(tier.isFeatureEnabled(AppAccessFeature.flashcards), isTrue);
    expect(tier.limitFor(AppAccessFeature.flashcards), 25);
  });
}
