import '../../../core/audit/audit_log_entry.dart';
import '../models/admin_dashboard_snapshot.dart';
import '../../../core/advertising/advertising_enums.dart';
import '../models/ad_campaign.dart';
import '../models/advertisement.dart';
import '../models/affiliate.dart';
import '../models/coupon.dart';
import '../models/partnership.dart';
import '../models/payment.dart';
import '../models/platform_user_extension.dart';
import '../models/seller.dart';
import '../models/platform_entitlement.dart';
import '../models/subscription.dart';
import '../models/subscription_plan.dart';
import '../models/user_notification.dart';
import '../enums/platform_enums.dart' show PaymentStatus;

/// Contratos de persistência do módulo plataforma (implementação: Firestore).
abstract class SubscriptionPlanRepository {
  Stream<List<SubscriptionPlan>> watchActivePlans();
  Stream<List<SubscriptionPlan>> watchAllPlans();
  Future<SubscriptionPlan?> getById(String id);
  Future<String> save(SubscriptionPlan plan);
  Future<void> delete(String id);
}

abstract class SubscriptionRepository {
  Stream<Subscription?> watchActiveForUser(String userId);
  Stream<List<Subscription>> watchForUser(String userId, {int limit = 20});
  Stream<List<Subscription>> watchAll({int limit = 200});
  Future<Subscription?> getById(String id);
  Future<String> save(Subscription subscription);
}

abstract class EntitlementRepository {
  Stream<List<PlatformEntitlement>> watchForUser(String userId);
  Future<String> save(String userId, PlatformEntitlement entitlement);
  Future<void> deactivate(String userId, String entitlementId);
}

abstract class PaymentRepository {
  Stream<List<Payment>> watchForUser(String userId, {int limit = 50});
  Stream<List<Payment>> watchAll({int limit = 200});
  Stream<List<Payment>> watchByStatus(PaymentStatus status, {int limit = 100});
  Future<Payment?> getById(String id);
  Future<String> save(Payment payment);
}

abstract class SellerRepository {
  Stream<List<Seller>> watchAll({bool activeOnly = true});
  Future<Seller?> getByUserId(String userId);
  Future<String> save(Seller seller);
  Future<void> delete(String id);
}

abstract class AffiliateRepository {
  Future<Affiliate?> getByCode(String code);
  Stream<List<Affiliate>> watchAll({bool activeOnly = true});
  Future<String> save(Affiliate affiliate);
  Future<void> delete(String id);
}

abstract class CouponRepository {
  Future<Coupon?> getByCode(String code);
  Stream<List<Coupon>> watchActive();
  Stream<List<Coupon>> watchAll();
  Future<String> save(Coupon coupon);
  Future<void> delete(String id);
}

abstract class PartnershipRepository {
  Stream<List<Partnership>> watchAll();
  Future<String> save(Partnership partnership);
  Future<void> delete(String id);
}

abstract class AdvertisementRepository {
  Stream<List<Advertisement>> watchByPlacement(
    String placementKey, {
    bool activeOnly = true,
  });
  Stream<List<Advertisement>> watchAll({int limit = 100});
  Future<String> save(Advertisement ad);
  Future<void> delete(String id);
}

abstract class AdCampaignRepository {
  Stream<List<AdCampaign>> watchAll({int limit = 200});
  Stream<List<AdCampaign>> watchByPlacement(AdPlacement placement, {int limit = 50});
  Future<AdCampaign?> getById(String id);
  Future<String> save(AdCampaign campaign);
  Future<void> delete(String id);
  Future<void> incrementImpressions(String id);
  Future<void> incrementClicks(String id);
  Future<void> incrementConversions(String id);
}

abstract class AuditLogRepository {
  Future<void> append(AuditLogEntry entry);
  Stream<List<AuditLogEntry>> watchRecent({int limit = 100});
}

abstract class UserNotificationRepository {
  Stream<List<UserNotification>> watchForUser(String userId, {int limit = 50});
  Future<String> save(UserNotification notification);
  Future<void> markRead(String userId, String notificationId);
}

abstract class PlatformUserRepository {
  Future<PlatformUserExtension?> getExtension(String userId);
  Future<void> mergeExtension(PlatformUserExtension extension);
}

abstract class AdminDashboardRepository {
  Future<AdminDashboardSnapshot> loadSnapshot();
}
