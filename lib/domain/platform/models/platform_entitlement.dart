import '../../../core/base/firestore_entity.dart';
import '../../../core/commercial/commercial_entitlement.dart';

/// Direito de acesso em `users/{uid}/platform_entitlements/{id}`.
class PlatformEntitlement implements FirestoreEntity {
  @override
  final String id;
  final CommercialEntitlementKey key;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final String? grantedByUserId;
  final CommercialGrantSource grantSource;
  final String? sellerId;
  final String? affiliateId;
  final String? couponId;
  final String? subscriptionId;
  final String? notes;
  final bool isActive;

  const PlatformEntitlement({
    required this.id,
    required this.key,
    this.grantedAt,
    this.expiresAt,
    this.grantedByUserId,
    this.grantSource = CommercialGrantSource.manual,
    this.sellerId,
    this.affiliateId,
    this.couponId,
    this.subscriptionId,
    this.notes,
    this.isActive = true,
  });

  bool get isValidNow {
    if (!isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  factory PlatformEntitlement.fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) {
      return PlatformEntitlement(
        id: id,
        key: CommercialEntitlementKey.premium,
      );
    }
    return PlatformEntitlement(
      id: id,
      key: CommercialEntitlementKey.fromKey(d['key']?.toString()) ??
          CommercialEntitlementKey.premium,
      grantedAt: FirestoreDates.from(d['grantedAt']),
      expiresAt: FirestoreDates.from(d['expiresAt']),
      grantedByUserId: d['grantedByUserId']?.toString(),
      grantSource:
          CommercialGrantSource.fromKey(d['grantSource']?.toString()),
      sellerId: d['sellerId']?.toString(),
      affiliateId: d['affiliateId']?.toString(),
      couponId: d['couponId']?.toString(),
      subscriptionId: d['subscriptionId']?.toString(),
      notes: d['notes']?.toString(),
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'key': key.key,
        if (grantedAt != null) 'grantedAt': FirestoreDates.to(grantedAt),
        if (expiresAt != null) 'expiresAt': FirestoreDates.to(expiresAt),
        if (grantedByUserId != null) 'grantedByUserId': grantedByUserId,
        'grantSource': grantSource.key,
        if (sellerId != null) 'sellerId': sellerId,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (couponId != null) 'couponId': couponId,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'isActive': isActive,
      };
}
