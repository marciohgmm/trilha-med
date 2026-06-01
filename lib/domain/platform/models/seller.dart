import '../../../core/base/firestore_entity.dart';

/// Vendedor / representante comercial (`platform_sellers`).
class Seller implements FirestoreEntity {
  @override
  final String id;
  final String userId;
  final String displayName;
  final String email;
  final double commissionPercent;
  final bool isActive;
  final int totalSales;
  final double totalRevenue;
  final Map<String, dynamic> metadata;

  const Seller({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    this.commissionPercent = 10,
    this.isActive = true,
    this.totalSales = 0,
    this.totalRevenue = 0,
    this.metadata = const {},
  });

  factory Seller.fromDoc(String id, Map<String, dynamic> d) {
    return Seller(
      id: id,
      userId: d['userId']?.toString() ?? '',
      displayName: d['displayName']?.toString() ?? '',
      email: d['email']?.toString() ?? '',
      commissionPercent: (d['commissionPercent'] as num?)?.toDouble() ?? 10,
      isActive: d['isActive'] as bool? ?? true,
      totalSales: (d['totalSales'] as num?)?.toInt() ?? 0,
      totalRevenue: (d['totalRevenue'] as num?)?.toDouble() ?? 0,
      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'email': email,
        'commissionPercent': commissionPercent,
        'isActive': isActive,
        'totalSales': totalSales,
        'totalRevenue': totalRevenue,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
