import '../../../core/base/firestore_entity.dart';
import '../../../core/commercial/commercial_entitlement.dart';

/// Plano de assinatura (`platform_subscription_plans`).
class SubscriptionPlan implements FirestoreEntity {
  @override
  final String id;
  final String name;
  final String description;
  final double priceMonthly;
  final double priceYearly;
  final String currency;
  final List<String> featureKeys;
  final PlanTier tier;
  final List<String> benefitLabels;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.description = '',
    this.priceMonthly = 0,
    this.priceYearly = 0,
    this.currency = 'BRL',
    this.featureKeys = const [],
    this.tier = PlanTier.premium,
    this.benefitLabels = const [],
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory SubscriptionPlan.fromDoc(String id, Map<String, dynamic> d) {
    return SubscriptionPlan(
      id: id,
      name: d['name']?.toString() ?? '',
      description: d['description']?.toString() ?? '',
      priceMonthly: (d['priceMonthly'] as num?)?.toDouble() ?? 0,
      priceYearly: (d['priceYearly'] as num?)?.toDouble() ?? 0,
      currency: d['currency']?.toString() ?? 'BRL',
      featureKeys: (d['featureKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tier: PlanTier.fromKey(d['tier']?.toString()),
      benefitLabels: (d['benefitLabels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: _parseBool(d['isActive'], defaultValue: true),
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: FirestoreDates.from(d['createdAt']),
    );
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (value is num) return value != 0;
    return defaultValue;
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'priceMonthly': priceMonthly,
        'priceYearly': priceYearly,
        'currency': currency,
        'featureKeys': featureKeys,
        'tier': tier.key,
        'benefitLabels': benefitLabels,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}
