import '../../../core/commercial/commercial_entitlement.dart';
import 'platform_entitlement.dart';
import 'subscription.dart';
import 'subscription_plan.dart';

/// Visão consolidada de acesso comercial do usuário (assinatura + entitlements).
class CommercialAccessSnapshot {
  final String userId;
  final Subscription? subscription;
  final SubscriptionPlan? plan;
  final List<PlatformEntitlement> entitlements;
  final SubscriptionDisplayStatus displayStatus;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final Set<CommercialEntitlementKey> activeKeys;

  const CommercialAccessSnapshot({
    required this.userId,
    this.subscription,
    this.plan,
    this.entitlements = const [],
    this.displayStatus = SubscriptionDisplayStatus.free,
    this.startedAt,
    this.expiresAt,
    this.activeKeys = const {},
  });

  bool get hasPremiumAccess => CommercialEntitlementKey.premiumAccessKeys
      .any((k) => activeKeys.contains(k));

  bool hasKey(CommercialEntitlementKey key) => activeKeys.contains(key);

  static CommercialAccessSnapshot free(String userId) => CommercialAccessSnapshot(
        userId: userId,
        displayStatus: SubscriptionDisplayStatus.free,
      );
}
