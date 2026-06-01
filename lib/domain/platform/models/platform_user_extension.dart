import '../../../core/base/firestore_entity.dart';
import '../../../core/permissions/app_role.dart';

/// Extensão comercial do perfil (`users` — campos opcionais futuros).
///
/// Não substitui `UserProfileService`; merge em `users/{uid}` quando ativado.
class PlatformUserExtension implements FirestoreEntity {
  @override
  final String id;
  final String email;
  final String displayName;
  final List<AppRole> roles;
  final String? sellerId;
  final String? affiliateId;
  final String? referredByAffiliateId;
  final String? activeSubscriptionId;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;

  const PlatformUserExtension({
    required this.id,
    required this.email,
    this.displayName = '',
    this.roles = const [AppRole.student],
    this.sellerId,
    this.affiliateId,
    this.referredByAffiliateId,
    this.activeSubscriptionId,
    this.metadata = const {},
    this.updatedAt,
  });

  factory PlatformUserExtension.fromDoc(String id, Map<String, dynamic> d) {
    final roleKeys = d['roles'];
    return PlatformUserExtension(
      id: id,
      email: d['email']?.toString() ?? '',
      displayName: d['displayName']?.toString() ?? '',
      roles: roleKeys is List
          ? AppRole.fromKeys(roleKeys.map((e) => e.toString()))
          : const [AppRole.student],
      sellerId: d['sellerId']?.toString(),
      affiliateId: d['affiliateId']?.toString(),
      referredByAffiliateId: d['referredByAffiliateId']?.toString(),
      activeSubscriptionId: d['activeSubscriptionId']?.toString(),
      metadata: Map<String, dynamic>.from(d['platformMetadata'] as Map? ?? {}),
      updatedAt: FirestoreDates.from(d['updatedAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'email': email,
        if (displayName.isNotEmpty) 'displayName': displayName,
        'roles': roles.map((r) => r.key).toList(),
        if (sellerId != null) 'sellerId': sellerId,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (referredByAffiliateId != null)
          'referredByAffiliateId': referredByAffiliateId,
        if (activeSubscriptionId != null)
          'activeSubscriptionId': activeSubscriptionId,
        if (metadata.isNotEmpty) 'platformMetadata': metadata,
      };
}
