import '../../../core/base/firestore_entity.dart';
import '../enums/platform_enums.dart';

/// Cupom de desconto (`platform_coupons`).
class Coupon implements FirestoreEntity {
  @override
  final String id;
  final String code;
  final CouponDiscountType discountType;
  final double discountValue;
  final int maxUses;
  final int usedCount;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<String> applicablePlanIds;
  final bool isActive;
  final String? affiliateId;
  final String? sellerId;

  const Coupon({
    required this.id,
    required this.code,
    this.discountType = CouponDiscountType.percent,
    this.discountValue = 0,
    this.maxUses = 0,
    this.usedCount = 0,
    this.validFrom,
    this.validUntil,
    this.applicablePlanIds = const [],
    this.isActive = true,
    this.affiliateId,
    this.sellerId,
  });

  bool get isUnlimited => maxUses <= 0;

  factory Coupon.fromDoc(String id, Map<String, dynamic> d) {
    return Coupon(
      id: id,
      code: d['code']?.toString() ?? '',
      discountType: CouponDiscountType.fromKey(d['discountType']?.toString()),
      discountValue: (d['discountValue'] as num?)?.toDouble() ?? 0,
      maxUses: (d['maxUses'] as num?)?.toInt() ?? 0,
      usedCount: (d['usedCount'] as num?)?.toInt() ?? 0,
      validFrom: FirestoreDates.from(d['validFrom']),
      validUntil: FirestoreDates.from(d['validUntil']),
      applicablePlanIds: (d['applicablePlanIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: d['isActive'] as bool? ?? true,
      affiliateId: d['affiliateId']?.toString(),
      sellerId: d['sellerId']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'code': code.toUpperCase(),
        'discountType': discountType.key,
        'discountValue': discountValue,
        'maxUses': maxUses,
        'usedCount': usedCount,
        if (validFrom != null) 'validFrom': FirestoreDates.to(validFrom),
        if (validUntil != null) 'validUntil': FirestoreDates.to(validUntil),
        'applicablePlanIds': applicablePlanIds,
        'isActive': isActive,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (sellerId != null) 'sellerId': sellerId,
      };
}
