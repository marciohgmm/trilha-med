import 'app_role.dart';

/// Permissões granulares para dashboard e APIs futuras.
enum AppPermission {
  // Conteúdo
  contentRead('content.read'),
  contentWrite('content.write'),

  // Comercial
  subscriptionManage('subscription.manage'),
  paymentView('payment.view'),
  paymentRefund('payment.refund'),
  couponManage('coupon.manage'),
  sellerManage('seller.manage'),
  affiliateManage('affiliate.manage'),
  partnershipManage('partnership.manage'),
  adManage('ad.manage'),
  campaignManage('campaign.manage'),

  // Admin / RBAC
  adminPanelAccess('admin.panel.access'),
  rbacManage('rbac.manage'),
  userManage('user.manage'),
  auditRead('audit.read'),
  dashboardView('dashboard.view'),
  analyticsView('analytics.view'),
  platformSettings('platform.settings'),
  featureFlagsManage('feature_flags.manage'),
  notificationBroadcast('notification.broadcast');

  final String key;
  const AppPermission(this.key);
}

/// Mapa papel → permissões padrão (extensível via Firestore no futuro).
class RolePermissionMatrix {
  RolePermissionMatrix._();

  static const Map<AppRole, Set<AppPermission>> defaults = {
    AppRole.user: {AppPermission.contentRead},
    AppRole.student: {AppPermission.contentRead},
    AppRole.masterAdmin: {
      AppPermission.adminPanelAccess,
      AppPermission.rbacManage,
      AppPermission.contentRead,
      AppPermission.contentWrite,
      AppPermission.subscriptionManage,
      AppPermission.paymentView,
      AppPermission.paymentRefund,
      AppPermission.couponManage,
      AppPermission.sellerManage,
      AppPermission.affiliateManage,
      AppPermission.partnershipManage,
      AppPermission.adManage,
      AppPermission.campaignManage,
      AppPermission.userManage,
      AppPermission.auditRead,
      AppPermission.dashboardView,
      AppPermission.analyticsView,
      AppPermission.platformSettings,
      AppPermission.featureFlagsManage,
      AppPermission.notificationBroadcast,
    },
    AppRole.admin: {
      AppPermission.adminPanelAccess,
      AppPermission.contentRead,
      AppPermission.contentWrite,
      AppPermission.subscriptionManage,
      AppPermission.paymentView,
      AppPermission.paymentRefund,
      AppPermission.couponManage,
      AppPermission.sellerManage,
      AppPermission.affiliateManage,
      AppPermission.partnershipManage,
      AppPermission.adManage,
      AppPermission.campaignManage,
      AppPermission.userManage,
      AppPermission.auditRead,
      AppPermission.dashboardView,
      AppPermission.platformSettings,
      AppPermission.featureFlagsManage,
      AppPermission.notificationBroadcast,
    },
    AppRole.seller: {
      AppPermission.contentRead,
      AppPermission.dashboardView,
    },
    AppRole.affiliate: {
      AppPermission.contentRead,
      AppPermission.dashboardView,
    },
    AppRole.partner: {
      AppPermission.contentRead,
      AppPermission.partnershipManage,
    },
    AppRole.finance: {
      AppPermission.paymentView,
      AppPermission.paymentRefund,
      AppPermission.auditRead,
      AppPermission.dashboardView,
      AppPermission.analyticsView,
    },
    AppRole.support: {
      AppPermission.adminPanelAccess,
      AppPermission.contentRead,
      AppPermission.userManage,
      AppPermission.auditRead,
    },
  };

  /// Todas as chaves conhecidas no código (seed + fallback).
  static List<String> get allKeys =>
      AppPermission.values.map((p) => p.key).toList();
}
