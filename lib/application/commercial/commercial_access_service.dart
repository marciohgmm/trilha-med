import 'dart:async';

import '../../core/commercial/commercial_entitlement.dart';
import '../../data/commercial_plan_catalog.dart';
import '../../domain/platform/enums/platform_enums.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../domain/platform/models/platform_entitlement.dart';
import '../../domain/platform/models/subscription.dart';
import '../../domain/platform/models/subscription_plan.dart';
import '../../domain/platform/repositories/platform_repository_contracts.dart';

/// Consolida assinatura + entitlements em tempo real para paywall e telas do aluno.
class CommercialAccessService {
  CommercialAccessService({
    required SubscriptionRepository subscriptionRepo,
    required EntitlementRepository entitlementRepo,
    required SubscriptionPlanRepository planRepo,
  })  : _subscriptionRepo = subscriptionRepo,
        _entitlementRepo = entitlementRepo,
        _planRepo = planRepo;

  final SubscriptionRepository _subscriptionRepo;
  final EntitlementRepository _entitlementRepo;
  final SubscriptionPlanRepository _planRepo;

  Stream<CommercialAccessSnapshot> watchAccess(String userId) {
    return _combineLatest(
      _subscriptionRepo.watchActiveForUser(userId),
      _entitlementRepo.watchForUser(userId),
      (subscription, entitlements) => _buildSnapshot(
        userId: userId,
        subscription: subscription,
        entitlements: entitlements,
      ),
    ).asyncMap((snap) async {
      if (snap.plan != null || snap.subscription == null) return snap;
      final planId = snap.subscription!.planId;
      if (planId.isEmpty || planId == CommercialPlanCatalog.freePlanId) {
        return snap;
      }
      final plan = await _planRepo.getById(planId);
      return _buildSnapshot(
        userId: snap.userId,
        subscription: snap.subscription,
        entitlements: snap.entitlements,
        plan: plan,
      );
    });
  }

  Future<CommercialAccessSnapshot> getAccess(String userId) async {
    Subscription? subscription;
    await for (final s in _subscriptionRepo.watchActiveForUser(userId)) {
      subscription = s;
      break;
    }
    List<PlatformEntitlement> entitlements = [];
    await for (final list in _entitlementRepo.watchForUser(userId)) {
      entitlements = list;
      break;
    }
    var snap = _buildSnapshot(
      userId: userId,
      subscription: subscription,
      entitlements: entitlements,
    );
    if (snap.subscription != null &&
        snap.plan == null &&
        snap.subscription!.planId.isNotEmpty &&
        snap.subscription!.planId != CommercialPlanCatalog.freePlanId) {
      final plan = await _planRepo.getById(snap.subscription!.planId);
      snap = _buildSnapshot(
        userId: snap.userId,
        subscription: snap.subscription,
        entitlements: snap.entitlements,
        plan: plan,
      );
    }
    return snap;
  }

  bool hasEntitlement(CommercialAccessSnapshot snap, CommercialEntitlementKey key) {
    return snap.activeKeys.contains(key);
  }

  CommercialAccessSnapshot _buildSnapshot({
    required String userId,
    Subscription? subscription,
    required List<PlatformEntitlement> entitlements,
    SubscriptionPlan? plan,
  }) {
    final validEntitlements = entitlements.where((e) => e.isValidNow).toList();
    final keys = validEntitlements.map((e) => e.key).toSet();

    final subActive = subscription != null && _subscriptionIsCurrentlyActive(subscription);
    if (subActive && plan?.tier == PlanTier.premium) {
      keys.add(CommercialEntitlementKey.premium);
    }

    final displayStatus = _resolveDisplayStatus(
      subscription: subscription,
      subActive: subActive,
      keys: keys,
    );

    DateTime? startedAt = subscription?.currentPeriodStart;
    DateTime? expiresAt = subscription?.currentPeriodEnd;

    for (final e in validEntitlements) {
      startedAt ??= e.grantedAt;
      if (e.key == CommercialEntitlementKey.premiumLifetime) {
        expiresAt = null;
      } else if (e.expiresAt != null) {
        expiresAt = expiresAt == null || e.expiresAt!.isAfter(expiresAt)
            ? e.expiresAt
            : expiresAt;
      }
    }

    return CommercialAccessSnapshot(
      userId: userId,
      subscription: subscription,
      plan: plan,
      entitlements: entitlements,
      displayStatus: displayStatus,
      startedAt: startedAt,
      expiresAt: expiresAt,
      activeKeys: keys,
    );
  }

  bool _subscriptionIsCurrentlyActive(Subscription subscription) {
    if (!subscription.isActive) return false;
    if (subscription.status == SubscriptionStatus.expired ||
        subscription.status == SubscriptionStatus.canceled) {
      return false;
    }
    final end = subscription.currentPeriodEnd;
    if (end != null && DateTime.now().isAfter(end)) return false;
    return true;
  }

  SubscriptionDisplayStatus _resolveDisplayStatus({
    Subscription? subscription,
    required bool subActive,
    required Set<CommercialEntitlementKey> keys,
  }) {
    if (keys.contains(CommercialEntitlementKey.premiumLifetime)) {
      return SubscriptionDisplayStatus.lifetime;
    }
    if (keys.contains(CommercialEntitlementKey.courtesyAccess)) {
      return SubscriptionDisplayStatus.courtesy;
    }
    if (keys.contains(CommercialEntitlementKey.betaTester)) {
      return SubscriptionDisplayStatus.beta;
    }
    if (subActive || keys.contains(CommercialEntitlementKey.premium)) {
      return SubscriptionDisplayStatus.active;
    }
    if (subscription != null &&
        (subscription.status == SubscriptionStatus.expired ||
            subscription.status == SubscriptionStatus.canceled ||
            (subscription.currentPeriodEnd != null &&
                DateTime.now().isAfter(subscription.currentPeriodEnd!)))) {
      return SubscriptionDisplayStatus.expired;
    }
    return SubscriptionDisplayStatus.free;
  }
}

Stream<R> _combineLatest<A, B, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  R Function(A, B) combiner,
) {
  return Stream.multi((controller) {
    A? latestA;
    B? latestB;
    var hasA = false;
    var hasB = false;

    void emit() {
      if (hasA && hasB) {
        controller.add(combiner(latestA as A, latestB as B));
      }
    }

    late final StreamSubscription<A> subA;
    late final StreamSubscription<B> subB;

    subA = streamA.listen(
      (value) {
        latestA = value;
        hasA = true;
        emit();
      },
      onError: controller.addError,
      onDone: () async {
        await subB.cancel();
        await controller.close();
      },
    );

    subB = streamB.listen(
      (value) {
        latestB = value;
        hasB = true;
        emit();
      },
      onError: controller.addError,
      onDone: () async {
        await subA.cancel();
        await controller.close();
      },
    );

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
  });
}
