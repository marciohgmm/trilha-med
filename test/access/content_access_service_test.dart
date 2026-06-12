import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/application/access/content_access_service.dart';
import 'package:flutter_application_1/core/access/app_access_feature.dart';
import 'package:flutter_application_1/core/commercial/commercial_entitlement.dart';
import 'package:flutter_application_1/data/app_access_default_seed.dart';
import 'package:flutter_application_1/domain/platform/models/commercial_access_snapshot.dart';
import 'package:flutter_application_1/models/access_usage_stats.dart';
import 'package:flutter_application_1/models/app_access_config_model.dart';
import 'package:flutter_application_1/models/app_access_plan_tier_model.dart';
import 'package:flutter_application_1/services/access/access_usage_repository.dart';
import 'package:flutter_application_1/services/access/app_access_config_service.dart';

void main() {
  late AccessUsageInMemory memory;
  late ContentAccessService service;
  late AppAccessConfigModel config;

  setUp(() {
    memory = AccessUsageInMemory();
    config = AppAccessDefaultSeed.defaults().copyWith(
      accessEnforcementEnabled: true,
    );
    service = ContentAccessService(
      configService: AppAccessConfigService.memory(config),
      commercialAccess: null,
      usageRepository: AccessUsageRepository.memory(memory),
    );
  });

  test('enforcement desligado permite consumo sem gravar bloqueio', () async {
    final off = AppAccessDefaultSeed.defaults();
    service = ContentAccessService(
      configService: AppAccessConfigService.memory(off),
      usageRepository: AccessUsageRepository.memory(memory),
    );
    final result = await service.tryConsumeFlashcard(
      userId: 'u1',
      cardId: 'c1',
    );
    expect(result.allowed, isTrue);
    expect(result.reason, ContentAccessBlockReason.enforcementOff);
    expect(memory.flashcardIds, isEmpty);
  });

  test('premium bypass via evaluateFeature não exige cota', () async {
    final premium = CommercialAccessSnapshot(
      userId: 'u1',
      activeKeys: {CommercialEntitlementKey.premium},
    );
    final result = await service.evaluateFeature(
      userId: 'u1',
      feature: AppAccessFeature.questions,
      snap: premium,
      stats: const AccessUsageStats(questionsConsumed: 999),
    );
    expect(result.allowed, isTrue);
    expect(result.reason, ContentAccessBlockReason.premiumBypass);
  });

  test('limit=0 no gratuito desabilita recurso', () async {
    config = config.copyWith(
      free: const AppAccessPlanTierModel(
        enabledByField: {'flashcardsEnabled': true},
        limitsByField: {'flashcardsLimit': 0},
      ),
    );
    service = ContentAccessService(
      configService: AppAccessConfigService.memory(config),
      usageRepository: AccessUsageRepository.memory(memory),
    );
    final result = await service.evaluateFeature(
      userId: 'u1',
      feature: AppAccessFeature.flashcards,
      snap: CommercialAccessSnapshot.free('u1'),
    );
    expect(result.allowed, isFalse);
    expect(result.reason, ContentAccessBlockReason.featureDisabled);
  });

  test('flashcard novo consome cota; repetido não incrementa', () async {
    final first = await service.tryConsumeFlashcard(
      userId: 'u1',
      cardId: 'c1',
    );
    expect(first.allowed, isTrue);
    expect(first.newlyConsumed, isTrue);
    expect(memory.stats.flashcardsConsumed, 1);

    final again = await service.tryConsumeFlashcard(
      userId: 'u1',
      cardId: 'c1',
    );
    expect(again.allowed, isTrue);
    expect(again.newlyConsumed, isFalse);
    expect(memory.stats.flashcardsConsumed, 1);
  });

  test('bloqueia ao atingir limite de questões', () async {
    config = config.copyWith(
      free: AppAccessPlanTierModel(
        enabledByField: {AppAccessFeature.questions.enabledField: true},
        limitsByField: {'questionsLimit': 1},
      ),
    );
    service = ContentAccessService(
      configService: AppAccessConfigService.memory(config),
      usageRepository: AccessUsageRepository.memory(memory),
    );

    final q1 = await service.tryConsumeQuestion(
      userId: 'u1',
      questionId: 'q1',
    );
    expect(q1.allowed, isTrue);

    final q2 = await service.tryConsumeQuestion(
      userId: 'u1',
      questionId: 'q2',
    );
    expect(q2.allowed, isFalse);
    expect(q2.reason, ContentAccessBlockReason.limitReached);
    expect(q2.used, 1);
    expect(q2.limit, 1);
  });
}
