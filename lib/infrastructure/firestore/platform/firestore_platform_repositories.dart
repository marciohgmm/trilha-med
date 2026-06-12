import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/advertising/advertising_enums.dart';
import '../../../core/audit/audit_log_entry.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../domain/platform/models/admin_dashboard_snapshot.dart';
import '../../../domain/platform/models/ad_campaign.dart';
import '../../../domain/platform/models/advertisement.dart';
import '../../../domain/platform/models/affiliate.dart';
import '../../../domain/platform/models/coupon.dart';
import '../../../domain/platform/models/partnership.dart';
import '../../../domain/platform/models/payment.dart';
import '../../../domain/platform/models/platform_entitlement.dart';
import '../../../domain/platform/models/platform_user_extension.dart';
import '../../../domain/platform/models/seller.dart';
import '../../../domain/platform/models/subscription.dart';
import '../../../domain/platform/models/subscription_plan.dart';
import '../../../domain/platform/models/user_notification.dart';
import '../../../domain/platform/repositories/platform_repository_contracts.dart';
import '../../../domain/platform/enums/platform_enums.dart'
    show PaymentStatus, SubscriptionStatus;

/// Implementações Firestore do módulo plataforma.
///
/// Não são usadas pelo app legado até integração explícita via [PlatformRegistry].
class FirestorePlatformRepositories {
  FirestorePlatformRepositories({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  late final SubscriptionPlanRepository subscriptionPlans =
      _SubscriptionPlanRepo(_db);
  late final SubscriptionRepository subscriptions = _SubscriptionRepo(_db);
  late final PaymentRepository payments = _PaymentRepo(_db);
  late final SellerRepository sellers = _SellerRepo(_db);
  late final AffiliateRepository affiliates = _AffiliateRepo(_db);
  late final CouponRepository coupons = _CouponRepo(_db);
  late final PartnershipRepository partnerships = _PartnershipRepo(_db);
  late final AdvertisementRepository advertisements = _AdvertisementRepo(_db);
  late final AdCampaignRepository adCampaigns = _AdCampaignRepo(_db);
  late final AuditLogRepository auditLogs = _AuditLogRepo(_db);
  late final UserNotificationRepository notifications =
      _UserNotificationRepo(_db);
  late final PlatformUserRepository users = _PlatformUserRepo(_db);
  late final EntitlementRepository entitlements = _EntitlementRepo(_db);
  late final AdminDashboardRepository dashboard = _AdminDashboardRepo(_db);
}

class _SubscriptionPlanRepo implements SubscriptionPlanRepository {
  _SubscriptionPlanRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformSubscriptionPlans);

  @override
  Stream<List<SubscriptionPlan>> watchActivePlans() {
    // Sem `where(isActive)` para evitar índice composto e docs legados sem o campo.
    // Regras Firestore já impedem leitura de planos inativos para alunos.
    return _col.orderBy('sortOrder').snapshots().map(
          (s) => s.docs
              .map((d) => SubscriptionPlan.fromDoc(d.id, d.data()))
              .where((p) => p.isActive)
              .toList(),
        );
  }

  @override
  Stream<List<SubscriptionPlan>> watchAllPlans() {
    return _col.orderBy('sortOrder').snapshots().map(
          (s) => s.docs
              .map((d) => SubscriptionPlan.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<SubscriptionPlan?> getById(String id) async {
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return SubscriptionPlan.fromDoc(d.id, d.data()!);
  }

  @override
  Future<String> save(SubscriptionPlan plan) async {
    final ref = plan.id.isEmpty ? _col.doc() : _col.doc(plan.id);
    await ref.set({
      ...plan.toMap(),
      'isActive': plan.isActive,
      'tier': plan.tier.key,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _SubscriptionRepo implements SubscriptionRepository {
  _SubscriptionRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformSubscriptions);

  @override
  Stream<Subscription?> watchActiveForUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          SubscriptionStatus.active.key,
          SubscriptionStatus.trialing.key,
        ])
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : Subscription.fromDoc(s.docs.first.id, s.docs.first.data()));
  }

  @override
  Stream<List<Subscription>> watchForUser(String userId, {int limit = 20}) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Subscription.fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<Subscription>> watchAll({int limit = 200}) {
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Subscription.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<Subscription?> getById(String id) async {
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return Subscription.fromDoc(d.id, d.data()!);
  }

  @override
  Future<String> save(Subscription subscription) async {
    final ref =
        subscription.id.isEmpty ? _col.doc() : _col.doc(subscription.id);
    await ref.set({
      ...subscription.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (subscription.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }
}

class _PaymentRepo implements PaymentRepository {
  _PaymentRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformPayments);

  @override
  Stream<List<Payment>> watchForUser(String userId, {int limit = 50}) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('paidAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Payment.fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<Payment>> watchAll({int limit = 200}) {
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Payment.fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<Payment>> watchByStatus(PaymentStatus status, {int limit = 100}) {
    return _col
        .where('status', isEqualTo: status.key)
        .orderBy('paidAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Payment.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<Payment?> getById(String id) async {
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return Payment.fromDoc(d.id, d.data()!);
  }

  @override
  Future<String> save(Payment payment) async {
    final ref = payment.id.isEmpty ? _col.doc() : _col.doc(payment.id);
    await ref.set({
      ...payment.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }
}

class _SellerRepo implements SellerRepository {
  _SellerRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformSellers);

  @override
  Stream<List<Seller>> watchAll({bool activeOnly = true}) {
    Query<Map<String, dynamic>> q = _col;
    if (activeOnly) q = q.where('isActive', isEqualTo: true);
    return q.snapshots().map(
          (s) => s.docs.map((d) => Seller.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<Seller?> getByUserId(String userId) async {
    final s = await _col.where('userId', isEqualTo: userId).limit(1).get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.first;
    return Seller.fromDoc(d.id, d.data());
  }

  @override
  Future<String> save(Seller seller) async {
    final ref = seller.id.isEmpty ? _col.doc() : _col.doc(seller.id);
    await ref.set(seller.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _AffiliateRepo implements AffiliateRepository {
  _AffiliateRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformAffiliates);

  @override
  Future<Affiliate?> getByCode(String code) async {
    final s = await _col
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.first;
    return Affiliate.fromDoc(d.id, d.data());
  }

  @override
  Stream<List<Affiliate>> watchAll({bool activeOnly = true}) {
    Query<Map<String, dynamic>> q = _col;
    if (activeOnly) q = q.where('isActive', isEqualTo: true);
    return q.snapshots().map(
          (s) => s.docs.map((d) => Affiliate.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<String> save(Affiliate affiliate) async {
    final ref = affiliate.id.isEmpty ? _col.doc() : _col.doc(affiliate.id);
    await ref.set(affiliate.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _CouponRepo implements CouponRepository {
  _CouponRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformCoupons);

  @override
  Future<Coupon?> getByCode(String code) async {
    final s = await _col
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.first;
    return Coupon.fromDoc(d.id, d.data());
  }

  @override
  Stream<List<Coupon>> watchActive() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Coupon.fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<Coupon>> watchAll() {
    return _col.snapshots().map(
          (s) => s.docs.map((d) => Coupon.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<String> save(Coupon coupon) async {
    final ref = coupon.id.isEmpty ? _col.doc() : _col.doc(coupon.id);
    await ref.set(coupon.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _PartnershipRepo implements PartnershipRepository {
  _PartnershipRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformPartnerships);

  @override
  Stream<List<Partnership>> watchAll() {
    return _col.snapshots().map(
          (s) =>
              s.docs.map((d) => Partnership.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<String> save(Partnership partnership) async {
    final ref =
        partnership.id.isEmpty ? _col.doc() : _col.doc(partnership.id);
    await ref.set(partnership.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _AdvertisementRepo implements AdvertisementRepository {
  _AdvertisementRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformAdvertisements);

  @override
  Stream<List<Advertisement>> watchByPlacement(
    String placementKey, {
    bool activeOnly = true,
  }) {
    Query<Map<String, dynamic>> q =
        _col.where('placement', isEqualTo: placementKey);
    if (activeOnly) q = q.where('isActive', isEqualTo: true);
    return q.orderBy('priority', descending: true).snapshots().map(
          (s) => s.docs
              .map((d) => Advertisement.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Advertisement>> watchAll({int limit = 100}) {
    return _col.limit(limit).snapshots().map(
          (s) => s.docs
              .map((d) => Advertisement.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<String> save(Advertisement ad) async {
    final ref = ad.id.isEmpty ? _col.doc() : _col.doc(ad.id);
    await ref.set(ad.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class _AdCampaignRepo implements AdCampaignRepository {
  _AdCampaignRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformAdCampaigns);

  @override
  Stream<List<AdCampaign>> watchAll({int limit = 200}) {
    return _col
        .orderBy('priority', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AdCampaign.fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<AdCampaign>> watchByPlacement(
    AdPlacement placement, {
    int limit = 50,
  }) {
    return _col
        .where('placements', arrayContains: placement.key)
        .where('adminStatus', isEqualTo: AdCampaignAdminStatus.active.key)
        .orderBy('priority', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AdCampaign.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<AdCampaign?> getById(String id) async {
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return AdCampaign.fromDoc(d.id, d.data()!);
  }

  @override
  Future<String> save(AdCampaign campaign) async {
    final ref = campaign.id.isEmpty ? _col.doc() : _col.doc(campaign.id);
    await ref.set({
      ...campaign.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (campaign.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();

  @override
  Future<void> incrementImpressions(String id) async {
    await _col.doc(id).update({
      'impressions': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> incrementClicks(String id) async {
    await _col.doc(id).update({
      'clicks': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> incrementConversions(String id) async {
    await _col.doc(id).update({
      'conversions': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _EntitlementRepo implements EntitlementRepository {
  _EntitlementRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String userId) => _db
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.userPlatformEntitlements);

  @override
  Stream<List<PlatformEntitlement>> watchForUser(String userId) {
    return _col(userId).snapshots().map(
          (s) => s.docs
              .map((d) => PlatformEntitlement.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<String> save(String userId, PlatformEntitlement entitlement) async {
    final ref = entitlement.id.isEmpty
        ? _col(userId).doc(entitlement.key.key)
        : _col(userId).doc(entitlement.id);
    await ref.set({
      ...entitlement.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (entitlement.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> deactivate(String userId, String entitlementId) async {
    await _col(userId).doc(entitlementId).set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class _AuditLogRepo implements AuditLogRepository {
  _AuditLogRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.platformAuditLogs);

  @override
  Future<void> append(AuditLogEntry entry) async {
    final ref = entry.id.isEmpty ? _col.doc() : _col.doc(entry.id);
    await ref.set({
      ...entry.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<AuditLogEntry>> watchRecent({int limit = 100}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AuditLogEntry.fromDoc(d.id, d.data())).toList());
  }
}

class _UserNotificationRepo implements UserNotificationRepository {
  _UserNotificationRepo(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String userId) => _db
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.userPlatformNotifications);

  @override
  Stream<List<UserNotification>> watchForUser(String userId, {int limit = 50}) {
    return _col(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => UserNotification.fromDoc(d.id, d.data()))
            .toList());
  }

  @override
  Future<String> save(UserNotification notification) async {
    final col = _col(notification.userId);
    final ref =
        notification.id.isEmpty ? col.doc() : col.doc(notification.id);
    await ref.set({
      ...notification.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> markRead(String userId, String notificationId) async {
    await _col(userId).doc(notificationId).update({'isRead': true});
  }
}

class _PlatformUserRepo implements PlatformUserRepository {
  _PlatformUserRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Future<PlatformUserExtension?> getExtension(String userId) async {
    final d = await _db.collection(FirestorePaths.users).doc(userId).get();
    if (!d.exists) return null;
    return PlatformUserExtension.fromDoc(d.id, d.data()!);
  }

  @override
  Future<void> mergeExtension(PlatformUserExtension extension) async {
    await _db.collection(FirestorePaths.users).doc(extension.id).set(
          extension.toMap(),
          SetOptions(merge: true),
        );
  }
}

class _AdminDashboardRepo implements AdminDashboardRepository {
  _AdminDashboardRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Future<AdminDashboardSnapshot> loadSnapshot() async {
    final now = DateTime.now();
    final thirtyDaysAgo = Timestamp.fromDate(
      now.subtract(const Duration(days: 30)),
    );
    final usersCol = _db.collection(FirestorePaths.users);

    final totalUsers = (await usersCol.count().get()).count ?? 0;
    final activeUsers = await _safeCount(
      usersCol.where('updatedAt', isGreaterThanOrEqualTo: thirtyDaysAgo),
    );
    final newUsers = await _safeCount(
      usersCol.where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo),
    );
    final adminsListed =
        (await _db.collection(FirestorePaths.admins).count().get()).count ?? 0;
    final legacyAdminUsers = await _countLegacyAdmins(usersCol);
    final totalAdmins = adminsListed + legacyAdminUsers;

    final sellers = await _safeCount(
      _db
          .collection(FirestorePaths.platformSellers)
          .where('isActive', isEqualTo: true),
    );
    final affiliates = await _safeCount(
      _db
          .collection(FirestorePaths.platformAffiliates)
          .where('isActive', isEqualTo: true),
    );
    final totalSubs =
        (await _db.collection(FirestorePaths.platformSubscriptions).count().get())
                .count ??
            0;
    final activeSubs = await _safeCount(
      _db
          .collection(FirestorePaths.platformSubscriptions)
          .where('status', isEqualTo: SubscriptionStatus.active.key),
    );
    final trialSubs = await _safeCount(
      _db
          .collection(FirestorePaths.platformSubscriptions)
          .where('status', isEqualTo: SubscriptionStatus.trialing.key),
    );
    final expiredSubs = await _safeCount(
      _db
          .collection(FirestorePaths.platformSubscriptions)
          .where('status', isEqualTo: SubscriptionStatus.expired.key),
    );
    final canceledSubs = await _safeCount(
      _db
          .collection(FirestorePaths.platformSubscriptions)
          .where('status', isEqualTo: SubscriptionStatus.canceled.key),
    );
    final pendingPayments = await _safeCount(
      _db
          .collection(FirestorePaths.platformPayments)
          .where('status', isEqualTo: PaymentStatus.pending.key),
    );
    final activeCoupons = await _safeCount(
      _db
          .collection(FirestorePaths.platformCoupons)
          .where('isActive', isEqualTo: true),
    );

    final auditSnap = await _db
        .collection(FirestorePaths.platformAuditLogs)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .get();
    final recentAudit = auditSnap.docs
        .map((d) => AuditLogEntry.fromDoc(d.id, d.data()))
        .toList();

    final projectedRevenue = await _projectedMonthlyRevenue(_db);
    final revenueMonth = await _revenueForMonth(_db, now);
    final revenueToday = await _revenueForDay(_db, now);
    final sellerMetrics = await _sellerConversionMetrics(_db);
    final affiliateMetrics = await _affiliateConversionMetrics(_db);

    return AdminDashboardSnapshot(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      newUsersLast30Days: newUsers,
      totalAdmins: totalAdmins,
      totalSellers: sellers,
      totalAffiliates: affiliates,
      totalSubscriptions: totalSubs,
      projectedRevenueMonthly: projectedRevenue,
      activeSubscriptions: activeSubs,
      trialingSubscriptions: trialSubs,
      expiredSubscriptions: expiredSubs + canceledSubs,
      revenueToday: revenueToday,
      revenueMonth: revenueMonth,
      pendingPayments: pendingPayments,
      activeCoupons: activeCoupons,
      sellerConversions: sellerMetrics,
      affiliateConversions: affiliateMetrics,
      recentAuditEvents: recentAudit,
      generatedAt: now,
    );
  }
}

Future<int> _safeCount(Query<Map<String, dynamic>> query) async {
  try {
    return (await query.count().get()).count ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<int> _countLegacyAdmins(
  CollectionReference<Map<String, dynamic>> usersCol,
) async {
  try {
    final snap = await usersCol.where('isAdmin', isEqualTo: true).count().get();
    return snap.count ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Receita projetada = soma dos preços mensais dos planos das assinaturas ativas.
Future<double> _projectedMonthlyRevenue(FirebaseFirestore db) async {
  try {
    final subsSnap = await db
        .collection(FirestorePaths.platformSubscriptions)
        .where('status', isEqualTo: SubscriptionStatus.active.key)
        .limit(200)
        .get();
    if (subsSnap.docs.isEmpty) return 0;

    final plansSnap = await db
        .collection(FirestorePaths.platformSubscriptionPlans)
        .get();
    final planPrices = <String, double>{};
    for (final d in plansSnap.docs) {
      planPrices[d.id] = (d.data()['priceMonthly'] as num?)?.toDouble() ?? 0;
    }

    var total = 0.0;
    for (final sub in subsSnap.docs) {
      final planId = sub.data()['planId']?.toString() ?? '';
      total += planPrices[planId] ?? 0;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

Future<double> _revenueForMonth(FirebaseFirestore db, DateTime now) async {
  try {
    final start = Timestamp.fromDate(DateTime(now.year, now.month, 1));
    final snap = await db
        .collection(FirestorePaths.platformPayments)
        .where('status', isEqualTo: PaymentStatus.succeeded.key)
        .where('paidAt', isGreaterThanOrEqualTo: start)
        .limit(500)
        .get();
    var total = 0.0;
    for (final d in snap.docs) {
      total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

Future<double> _revenueForDay(FirebaseFirestore db, DateTime now) async {
  try {
    final start = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final snap = await db
        .collection(FirestorePaths.platformPayments)
        .where('status', isEqualTo: PaymentStatus.succeeded.key)
        .where('paidAt', isGreaterThanOrEqualTo: start)
        .limit(200)
        .get();
    var total = 0.0;
    for (final d in snap.docs) {
      total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

Future<List<CommercialAttributionMetric>> _sellerConversionMetrics(
  FirebaseFirestore db,
) async {
  try {
    final snap = await db.collection(FirestorePaths.platformSellers).limit(50).get();
    return snap.docs.map((d) {
      final data = d.data();
      return CommercialAttributionMetric(
        id: d.id,
        label: data['displayName']?.toString().isNotEmpty == true
            ? data['displayName'].toString()
            : d.id,
        conversions: (data['totalSales'] as num?)?.toInt() ?? 0,
        revenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.conversions.compareTo(a.conversions));
  } catch (_) {
    return const [];
  }
}

Future<List<CommercialAttributionMetric>> _affiliateConversionMetrics(
  FirebaseFirestore db,
) async {
  try {
    final snap =
        await db.collection(FirestorePaths.platformAffiliates).limit(50).get();
    return snap.docs.map((d) {
      final data = d.data();
      return CommercialAttributionMetric(
        id: d.id,
        label: data['code']?.toString() ?? d.id,
        conversions: (data['conversions'] as num?)?.toInt() ?? 0,
        revenue: (data['totalCommission'] as num?)?.toDouble() ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.conversions.compareTo(a.conversions));
  } catch (_) {
    return const [];
  }
}
