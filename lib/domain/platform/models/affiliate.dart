import '../../../core/base/firestore_entity.dart';

/// Afiliado (`platform_affiliates`).
class Affiliate implements FirestoreEntity {
  @override
  final String id;
  final String userId;
  final String code;
  final String displayName;
  final double commissionPercent;
  final bool isActive;
  final int clicks;
  final int conversions;
  final double totalCommission;
  final Map<String, dynamic> metadata;

  const Affiliate({
    required this.id,
    required this.userId,
    required this.code,
    required this.displayName,
    this.commissionPercent = 15,
    this.isActive = true,
    this.clicks = 0,
    this.conversions = 0,
    this.totalCommission = 0,
    this.metadata = const {},
  });

  factory Affiliate.fromDoc(String id, Map<String, dynamic> d) {
    return Affiliate(
      id: id,
      userId: d['userId']?.toString() ?? '',
      code: d['code']?.toString() ?? '',
      displayName: d['displayName']?.toString() ?? '',
      commissionPercent: (d['commissionPercent'] as num?)?.toDouble() ?? 15,
      isActive: d['isActive'] as bool? ?? true,
      clicks: (d['clicks'] as num?)?.toInt() ?? 0,
      conversions: (d['conversions'] as num?)?.toInt() ?? 0,
      totalCommission: (d['totalCommission'] as num?)?.toDouble() ?? 0,
      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'code': code,
        'displayName': displayName,
        'commissionPercent': commissionPercent,
        'isActive': isActive,
        'clicks': clicks,
        'conversions': conversions,
        'totalCommission': totalCommission,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
