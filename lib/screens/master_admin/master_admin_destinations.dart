import 'package:flutter/material.dart';

import '../../core/permissions/app_permission.dart';
import 'modules/app_access_config_admin_page.dart';
import 'modules/feature_flags_admin_page.dart';
import 'modules/master_admin_ads_page.dart';
import 'modules/master_admin_affiliates_page.dart';
import 'modules/master_admin_analytics_page.dart';
import 'modules/master_admin_audit_page.dart';
import 'modules/master_admin_campaign_dashboard_page.dart';
import 'modules/master_admin_campaigns_page.dart';
import 'modules/master_admin_coupons_page.dart';
import 'modules/master_admin_dashboard_page.dart';
import 'modules/master_admin_partners_page.dart';
import 'modules/master_admin_payments_page.dart';
import 'modules/master_admin_plans_page.dart';
import 'modules/master_admin_push_page.dart';
import 'modules/master_admin_sellers_page.dart';
import 'modules/master_admin_settings_page.dart';
import 'modules/master_admin_subscriptions_page.dart';
import 'modules/master_admin_users_page.dart';

/// Destino do painel mestre — permissão RBAC + rota de auditoria.
class MasterAdminDestination {
  final String id;
  final String label;
  final IconData icon;
  final String permissionKey;
  final String routeName;
  final Widget Function() pageBuilder;

  const MasterAdminDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.permissionKey,
    required this.routeName,
    required this.pageBuilder,
  });
}

/// Lista ordenada — adicione novos módulos aqui.
class MasterAdminDestinations {
  MasterAdminDestinations._();

  static const _brand = Color(0xFF1E3A8A);

  static Color get brandColor => _brand;

  static final List<MasterAdminDestination> all = [
    MasterAdminDestination(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      permissionKey: AppPermission.dashboardView.key,
      routeName: 'master.dashboard',
      pageBuilder: () => const MasterAdminDashboardPage(),
    ),
    MasterAdminDestination(
      id: 'analytics',
      label: 'Analytics',
      icon: Icons.insights_outlined,
      permissionKey: AppPermission.analyticsView.key,
      routeName: 'master.analytics',
      pageBuilder: () => const MasterAdminAnalyticsPage(),
    ),
    MasterAdminDestination(
      id: 'users',
      label: 'Usuários',
      icon: Icons.people_outline,
      permissionKey: AppPermission.userManage.key,
      routeName: 'master.users',
      pageBuilder: () => const MasterAdminUsersPage(),
    ),
    MasterAdminDestination(
      id: 'subscriptions',
      label: 'Assinaturas',
      icon: Icons.card_membership_outlined,
      permissionKey: AppPermission.subscriptionManage.key,
      routeName: 'master.subscriptions',
      pageBuilder: () => const MasterAdminSubscriptionsPage(),
    ),
    MasterAdminDestination(
      id: 'payments',
      label: 'Pagamentos',
      icon: Icons.payments_outlined,
      permissionKey: AppPermission.paymentView.key,
      routeName: 'master.payments',
      pageBuilder: () => const MasterAdminPaymentsPage(),
    ),
    MasterAdminDestination(
      id: 'plans',
      label: 'Planos',
      icon: Icons.layers_outlined,
      permissionKey: AppPermission.subscriptionManage.key,
      routeName: 'master.plans',
      pageBuilder: () => const MasterAdminPlansPage(),
    ),
    MasterAdminDestination(
      id: 'sellers',
      label: 'Vendedores',
      icon: Icons.storefront_outlined,
      permissionKey: AppPermission.sellerManage.key,
      routeName: 'master.sellers',
      pageBuilder: () => const MasterAdminSellersPage(),
    ),
    MasterAdminDestination(
      id: 'affiliates',
      label: 'Afiliados',
      icon: Icons.hub_outlined,
      permissionKey: AppPermission.affiliateManage.key,
      routeName: 'master.affiliates',
      pageBuilder: () => const MasterAdminAffiliatesPage(),
    ),
    MasterAdminDestination(
      id: 'coupons',
      label: 'Cupons',
      icon: Icons.local_offer_outlined,
      permissionKey: AppPermission.couponManage.key,
      routeName: 'master.coupons',
      pageBuilder: () => const MasterAdminCouponsPage(),
    ),
    MasterAdminDestination(
      id: 'partners',
      label: 'Parceiros',
      icon: Icons.handshake_outlined,
      permissionKey: AppPermission.partnershipManage.key,
      routeName: 'master.partners',
      pageBuilder: () => const MasterAdminPartnersPage(),
    ),
    MasterAdminDestination(
      id: 'push',
      label: 'Push',
      icon: Icons.notifications_active_outlined,
      permissionKey: AppPermission.notificationBroadcast.key,
      routeName: 'master.push',
      pageBuilder: () => const MasterAdminPushPage(),
    ),
    MasterAdminDestination(
      id: 'campaigns',
      label: 'Campanhas',
      icon: Icons.campaign_outlined,
      permissionKey: AppPermission.campaignManage.key,
      routeName: 'master.campaigns',
      pageBuilder: () => const MasterAdminCampaignsPage(),
    ),
    MasterAdminDestination(
      id: 'campaign_dashboard',
      label: 'Dashboard campanhas',
      icon: Icons.analytics_outlined,
      permissionKey: AppPermission.campaignManage.key,
      routeName: 'master.campaign_dashboard',
      pageBuilder: () => const MasterAdminCampaignDashboardPage(),
    ),
    MasterAdminDestination(
      id: 'ads',
      label: 'Propagandas (legado)',
      icon: Icons.campaign_outlined,
      permissionKey: AppPermission.adManage.key,
      routeName: 'master.ads',
      pageBuilder: () => const MasterAdminAdsPage(),
    ),
    MasterAdminDestination(
      id: 'feature_flags',
      label: 'Feature flags',
      icon: Icons.toggle_on_outlined,
      permissionKey: AppPermission.featureFlagsManage.key,
      routeName: 'master.feature_flags',
      pageBuilder: () => const FeatureFlagsAdminPage(),
    ),
    MasterAdminDestination(
      id: 'access_config',
      label: 'Gratuito vs Premium',
      icon: Icons.lock_open_outlined,
      permissionKey: AppPermission.platformSettings.key,
      routeName: 'master.access_config',
      pageBuilder: () => const AppAccessConfigAdminPage(),
    ),
    MasterAdminDestination(
      id: 'audit',
      label: 'Auditoria',
      icon: Icons.fact_check_outlined,
      permissionKey: AppPermission.auditRead.key,
      routeName: 'master.audit',
      pageBuilder: () => const MasterAdminAuditPage(),
    ),
    MasterAdminDestination(
      id: 'settings',
      label: 'Configurações',
      icon: Icons.settings_outlined,
      permissionKey: AppPermission.platformSettings.key,
      routeName: 'master.settings',
      pageBuilder: () => const MasterAdminSettingsPage(),
    ),
  ];
}
