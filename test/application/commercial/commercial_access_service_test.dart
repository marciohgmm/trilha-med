import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/application/commercial/commercial_access_service.dart';
import 'package:flutter_application_1/core/commercial/commercial_entitlement.dart';
import 'package:flutter_application_1/domain/platform/enums/platform_enums.dart';
import 'package:flutter_application_1/domain/platform/models/platform_entitlement.dart';
import 'package:flutter_application_1/domain/platform/models/subscription.dart';
import 'package:flutter_application_1/domain/platform/models/subscription_plan.dart';

import '../../helpers/fake_platform_repositories.dart';

void main() {
  late FakeSubscriptionRepository subRepo;
  late FakeEntitlementRepository entRepo;
  late FakeSubscriptionPlanRepository planRepo;
  late CommercialAccessService service;

  setUp(() {
    subRepo = FakeSubscriptionRepository();
    entRepo = FakeEntitlementRepository();
    planRepo = FakeSubscriptionPlanRepository();
    service = CommercialAccessService(
      subscriptionRepo: subRepo,
      entitlementRepo: entRepo,
      planRepo: planRepo,
    );
  });

  test('usuário sem assinatura é free', () async {
    final snap = await service.getAccess('user_free');
    expect(snap.displayStatus, SubscriptionDisplayStatus.free);
    expect(snap.hasPremiumAccess, isFalse);
  });

  test('assinatura premium ativa concede premium', () async {
    final end = DateTime.now().add(const Duration(days: 30));
    subRepo.emit(
      Subscription(
        id: 'sub1',
        userId: 'u1',
        planId: 'premium',
        status: SubscriptionStatus.active,
        currentPeriodEnd: end,
      ),
    );
    planRepo = FakeSubscriptionPlanRepository(
      plan: SubscriptionPlan(
        id: 'premium',
        name: 'Premium',
        tier: PlanTier.premium,
      ),
    );
    service = CommercialAccessService(
      subscriptionRepo: subRepo,
      entitlementRepo: entRepo,
      planRepo: planRepo,
    );

    final snap = await service.getAccess('u1');
    expect(snap.hasPremiumAccess, isTrue);
    expect(snap.displayStatus, SubscriptionDisplayStatus.active);
  });

  test('assinatura expirada não concede premium', () async {
    subRepo.emit(
      Subscription(
        id: 'sub2',
        userId: 'u2',
        planId: 'premium',
        status: SubscriptionStatus.active,
        currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    final snap = await service.getAccess('u2');
    expect(snap.hasPremiumAccess, isFalse);
    expect(snap.displayStatus, SubscriptionDisplayStatus.expired);
  });

  test('entitlement lifetime concede premium', () async {
    entRepo.emit([
      PlatformEntitlement(
        id: 'e1',
        key: CommercialEntitlementKey.premiumLifetime,
        grantedAt: DateTime.now(),
      ),
    ]);
    final snap = await service.getAccess('u3');
    expect(snap.hasPremiumAccess, isTrue);
    expect(snap.displayStatus, SubscriptionDisplayStatus.lifetime);
  });

  test('entitlement expirado é ignorado', () async {
    entRepo.emit([
      PlatformEntitlement(
        id: 'e2',
        key: CommercialEntitlementKey.premium,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);
    final snap = await service.getAccess('u4');
    expect(snap.hasPremiumAccess, isFalse);
  });
}
