import '../../../core/base/firestore_entity.dart';
import '../../../core/commercial/commercial_entitlement.dart';
import '../enums/platform_enums.dart';

/// Assinatura de usuário (`platform_subscriptions`).
class Subscription implements FirestoreEntity {
  @override
  final String id;
  final String userId;
  final String planId;
  final SubscriptionStatus status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? canceledAt;
  final String? couponId;
  final String? sellerId;
  final String? affiliateId;
  final CommercialGrantSource? grantSource;
  final String? grantNotes;
  final String? externalProviderId;
  final Map<String, dynamic> metadata;

  const Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    this.status = SubscriptionStatus.trialing,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.canceledAt,
    this.couponId,
    this.sellerId,
    this.affiliateId,
    this.grantSource,
    this.grantNotes,
    this.externalProviderId,
    this.metadata = const {},
  });

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;

  factory Subscription.fromDoc(String id, Map<String, dynamic> d) {
    return Subscription(
      id: id,
      userId: d['userId']?.toString() ?? '',
      planId: d['planId']?.toString() ?? '',
      status: SubscriptionStatus.fromKey(d['status']?.toString()),
      currentPeriodStart: FirestoreDates.from(d['currentPeriodStart']),
      currentPeriodEnd: FirestoreDates.from(d['currentPeriodEnd']),
      canceledAt: FirestoreDates.from(d['canceledAt']),
      couponId: d['couponId']?.toString(),
      sellerId: d['sellerId']?.toString(),
      affiliateId: d['affiliateId']?.toString(),
      grantSource: d['grantSource'] != null
          ? CommercialGrantSource.fromKey(d['grantSource']?.toString())
          : null,
      grantNotes: d['grantNotes']?.toString(),
      externalProviderId: d['externalProviderId']?.toString(),
      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'planId': planId,
        'status': status.key,
        if (currentPeriodStart != null)
          'currentPeriodStart': FirestoreDates.to(currentPeriodStart),
        if (currentPeriodEnd != null)
          'currentPeriodEnd': FirestoreDates.to(currentPeriodEnd),
        if (canceledAt != null) 'canceledAt': FirestoreDates.to(canceledAt),
        if (couponId != null) 'couponId': couponId,
        if (sellerId != null) 'sellerId': sellerId,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (grantSource != null) 'grantSource': grantSource!.key,
        if (grantNotes != null && grantNotes!.isNotEmpty) 'grantNotes': grantNotes,
        if (externalProviderId != null)
          'externalProviderId': externalProviderId,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
