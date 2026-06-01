import '../../core/audit/audit_event_type.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../domain/platform/enums/platform_enums.dart';
import '../../domain/platform/models/affiliate.dart';
import '../../domain/platform/models/coupon.dart';
import '../../domain/platform/models/platform_entitlement.dart';
import '../../domain/platform/models/seller.dart';
import '../../domain/platform/models/subscription.dart';
import '../../domain/platform/repositories/platform_repository_contracts.dart';
import '../platform/platform_audit_service.dart';

/// Concessão e revogação manual de acesso (Painel Mestre) — sem gateway de pagamento.
class CommercialAdminService {
  CommercialAdminService({
    required SubscriptionRepository subscriptionRepo,
    required EntitlementRepository entitlementRepo,
    required SubscriptionPlanRepository planRepo,
    required SellerRepository sellerRepo,
    required AffiliateRepository affiliateRepo,
    required CouponRepository couponRepo,
    required PlatformAuditService audit,
  })  : _subscriptionRepo = subscriptionRepo,
        _entitlementRepo = entitlementRepo,
        _planRepo = planRepo,
        _sellerRepo = sellerRepo,
        _affiliateRepo = affiliateRepo,
        _couponRepo = couponRepo,
        _audit = audit;

  final SubscriptionRepository _subscriptionRepo;
  final EntitlementRepository _entitlementRepo;
  final SubscriptionPlanRepository _planRepo;
  final SellerRepository _sellerRepo;
  final AffiliateRepository _affiliateRepo;
  final CouponRepository _couponRepo;
  final PlatformAuditService _audit;

  /// Concede acesso comercial manual com rastreamento de vendedor/afiliado/cupom.
  Future<String> grantAccess({
    required String actorUserId,
    required String targetUserId,
    required CommercialGrantSource grantSource,
    required CommercialEntitlementKey entitlementKey,
    String? planId,
    DateTime? expiresAt,
    String? sellerId,
    String? affiliateId,
    String? couponCode,
    String? notes,
  }) async {
    final now = DateTime.now();
    String? couponId;
    if (couponCode != null && couponCode.trim().isNotEmpty) {
      final coupon = await _couponRepo.getByCode(couponCode.trim());
      if (coupon != null) {
        couponId = coupon.id;
        await _incrementCouponUse(coupon);
      }
    }

    final resolvedPlanId = planId ?? await _defaultPremiumPlanId();
    final subscriptionId = await _subscriptionRepo.save(
      Subscription(
        id: '',
        userId: targetUserId,
        planId: resolvedPlanId,
        status: SubscriptionStatus.active,
        currentPeriodStart: now,
        currentPeriodEnd: entitlementKey == CommercialEntitlementKey.premiumLifetime
            ? null
            : expiresAt,
        couponId: couponId,
        sellerId: sellerId,
        affiliateId: affiliateId,
        grantSource: grantSource,
        grantNotes: notes,
        externalProviderId: 'manual',
      ),
    );

    await _entitlementRepo.save(
      targetUserId,
      PlatformEntitlement(
        id: '',
        key: entitlementKey,
        grantedAt: now,
        expiresAt:
            entitlementKey == CommercialEntitlementKey.premiumLifetime ? null : expiresAt,
        grantedByUserId: actorUserId,
        grantSource: grantSource,
        sellerId: sellerId,
        affiliateId: affiliateId,
        couponId: couponId,
        subscriptionId: subscriptionId,
        notes: notes,
        isActive: true,
      ),
    );

    if (sellerId != null && sellerId.isNotEmpty) {
      await _trackSellerConversion(sellerId);
    }
    if (affiliateId != null && affiliateId.isNotEmpty) {
      await _trackAffiliateConversion(affiliateId);
    }

    await _audit.log(
      eventType: AuditEventType.accessGranted,
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      entityType: 'subscription',
      entityId: subscriptionId,
      metadata: {
        'grantSource': grantSource.key,
        'entitlementKey': entitlementKey.key,
        if (sellerId != null) 'sellerId': sellerId,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (couponId != null) 'couponId': couponId,
      },
    );

    return subscriptionId;
  }

  Future<void> grantLifetime({
    required String actorUserId,
    required String targetUserId,
    String? sellerId,
    String? affiliateId,
    String? couponCode,
    String? notes,
  }) =>
      grantAccess(
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        grantSource: CommercialGrantSource.lifetime,
        entitlementKey: CommercialEntitlementKey.premiumLifetime,
        sellerId: sellerId,
        affiliateId: affiliateId,
        couponCode: couponCode,
        notes: notes,
      );

  Future<void> grantCourtesy({
    required String actorUserId,
    required String targetUserId,
    DateTime? expiresAt,
    String? sellerId,
    String? affiliateId,
    String? notes,
  }) =>
      grantAccess(
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        grantSource: CommercialGrantSource.courtesy,
        entitlementKey: CommercialEntitlementKey.courtesyAccess,
        expiresAt: expiresAt,
        sellerId: sellerId,
        affiliateId: affiliateId,
        notes: notes,
      );

  Future<void> grantBetaTester({
    required String actorUserId,
    required String targetUserId,
    DateTime? expiresAt,
    String? notes,
  }) =>
      grantAccess(
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        grantSource: CommercialGrantSource.beta,
        entitlementKey: CommercialEntitlementKey.betaTester,
        expiresAt: expiresAt,
        notes: notes,
      );

  Future<void> grantPromotional({
    required String actorUserId,
    required String targetUserId,
    required DateTime expiresAt,
    String? sellerId,
    String? affiliateId,
    String? couponCode,
    String? notes,
  }) =>
      grantAccess(
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        grantSource: CommercialGrantSource.promotional,
        entitlementKey: CommercialEntitlementKey.premium,
        expiresAt: expiresAt,
        sellerId: sellerId,
        affiliateId: affiliateId,
        couponCode: couponCode,
        notes: notes,
      );

  Future<void> grantLottery({
    required String actorUserId,
    required String targetUserId,
    required DateTime expiresAt,
    String? notes,
  }) =>
      grantAccess(
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        grantSource: CommercialGrantSource.lottery,
        entitlementKey: CommercialEntitlementKey.premium,
        expiresAt: expiresAt,
        notes: notes,
      );

  Future<void> grantSellerAccess({
    required String actorUserId,
    required String targetUserId,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _entitlementRepo.save(
      targetUserId,
      PlatformEntitlement(
        id: '',
        key: CommercialEntitlementKey.sellerAccess,
        grantedAt: now,
        grantedByUserId: actorUserId,
        grantSource: CommercialGrantSource.manual,
        notes: notes,
        isActive: true,
      ),
    );
    await _audit.log(
      eventType: AuditEventType.accessGranted,
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      entityType: 'entitlement',
      entityId: CommercialEntitlementKey.sellerAccess.key,
      metadata: {'entitlementKey': CommercialEntitlementKey.sellerAccess.key},
    );
  }

  /// Revoga todos os entitlements ativos e cancela assinatura ativa do usuário.
  Future<void> revokeAccess({
    required String actorUserId,
    required String targetUserId,
    String? reason,
  }) async {
    final entitlements = await _entitlementRepo
        .watchForUser(targetUserId)
        .first
        .catchError((_) => <PlatformEntitlement>[]);

    for (final e in entitlements.where((e) => e.isActive)) {
      await _entitlementRepo.deactivate(targetUserId, e.id);
    }

    final subscription = await _subscriptionRepo.watchActiveForUser(targetUserId).first;
    if (subscription != null) {
      await _subscriptionRepo.save(
        Subscription(
          id: subscription.id,
          userId: subscription.userId,
          planId: subscription.planId,
          status: SubscriptionStatus.canceled,
          currentPeriodStart: subscription.currentPeriodStart,
          currentPeriodEnd: subscription.currentPeriodEnd,
          canceledAt: DateTime.now(),
          couponId: subscription.couponId,
          sellerId: subscription.sellerId,
          affiliateId: subscription.affiliateId,
          grantSource: subscription.grantSource,
          grantNotes: reason ?? subscription.grantNotes,
          externalProviderId: subscription.externalProviderId,
          metadata: subscription.metadata,
        ),
      );
    }

    await _audit.log(
      eventType: AuditEventType.subscriptionCanceled,
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      entityType: 'user_access',
      entityId: targetUserId,
      metadata: {if (reason != null) 'reason': reason},
    );
  }

  Future<String> _defaultPremiumPlanId() async {
    try {
      final plans = await _planRepo.watchActivePlans().first;
      for (final p in plans) {
        if (p.tier == PlanTier.premium) return p.id;
      }
      return plans.isNotEmpty ? plans.first.id : 'premium';
    } catch (_) {
      return 'premium';
    }
  }

  Future<void> _incrementCouponUse(Coupon coupon) async {
    await _couponRepo.save(
      Coupon(
        id: coupon.id,
        code: coupon.code,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
        maxUses: coupon.maxUses,
        usedCount: coupon.usedCount + 1,
        validFrom: coupon.validFrom,
        validUntil: coupon.validUntil,
        applicablePlanIds: coupon.applicablePlanIds,
        isActive: coupon.isActive,
        affiliateId: coupon.affiliateId,
        sellerId: coupon.sellerId,
      ),
    );
    await _audit.log(
      eventType: AuditEventType.couponApplied,
      actorUserId: 'system',
      entityType: 'coupon',
      entityId: coupon.id,
      metadata: {'code': coupon.code},
    );
  }

  Future<void> _trackSellerConversion(String sellerId) async {
    final sellers = await _sellerRepo.watchAll(activeOnly: false).first;
    Seller? seller;
    for (final s in sellers) {
      if (s.id == sellerId) {
        seller = s;
        break;
      }
    }
    if (seller == null) return;
    await _sellerRepo.save(
      Seller(
        id: seller.id,
        userId: seller.userId,
        displayName: seller.displayName,
        email: seller.email,
        commissionPercent: seller.commissionPercent,
        isActive: seller.isActive,
        totalSales: seller.totalSales + 1,
        totalRevenue: seller.totalRevenue,
        metadata: seller.metadata,
      ),
    );
    await _audit.log(
      eventType: AuditEventType.sellerCommission,
      actorUserId: 'system',
      entityType: 'seller',
      entityId: sellerId,
    );
  }

  Future<void> _trackAffiliateConversion(String affiliateId) async {
    final affiliates = await _affiliateRepo.watchAll(activeOnly: false).first;
    Affiliate? affiliate;
    for (final a in affiliates) {
      if (a.id == affiliateId) {
        affiliate = a;
        break;
      }
    }
    if (affiliate == null) return;
    await _affiliateRepo.save(
      Affiliate(
        id: affiliate.id,
        userId: affiliate.userId,
        code: affiliate.code,
        displayName: affiliate.displayName,
        commissionPercent: affiliate.commissionPercent,
        isActive: affiliate.isActive,
        clicks: affiliate.clicks,
        conversions: affiliate.conversions + 1,
        totalCommission: affiliate.totalCommission,
        metadata: affiliate.metadata,
      ),
    );
    await _audit.log(
      eventType: AuditEventType.affiliateConversion,
      actorUserId: 'system',
      entityType: 'affiliate',
      entityId: affiliateId,
    );
  }
}
