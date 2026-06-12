import '../../application/admin/admin_access_service.dart';
import '../access/app_access_service.dart';
import '../access/content_access_service.dart';
import '../analytics/analytics_dashboard_service.dart';
import '../push/push_campaign_admin_service.dart';
import '../../infrastructure/firestore/platform/firestore_platform_repositories.dart';
import '../advertising/ad_campaign_admin_service.dart';
import '../advertising/advertising_campaign_service.dart';
import '../commercial/commercial_access_service.dart';
import '../commercial/commercial_admin_service.dart';
import '../commercial/mercado_pago_checkout_service.dart';
import '../rbac/rbac_service.dart';
import 'master_admin_dashboard_service.dart';
import 'platform_audit_service.dart';

/// Ponto único de acesso ao módulo plataforma (lazy singleton).
///
/// **Não é inicializado em [main.dart]** — o app legado não depende deste registry.
/// Quando for integrar checkout/admin dashboard:
/// ```dart
/// final platform = PlatformRegistry.instance;
/// final plans = platform.repositories.subscriptionPlans.watchActivePlans();
/// ```
class PlatformRegistry {
  PlatformRegistry._();
  static final PlatformRegistry instance = PlatformRegistry._();

  FirestorePlatformRepositories? _repos;
  PlatformAuditService? _audit;
  MasterAdminDashboardService? _masterDashboard;
  AnalyticsDashboardService? _analyticsDashboard;
  PushCampaignAdminService? _pushCampaignAdmin;
  CommercialAccessService? _commercialAccess;
  CommercialAdminService? _commercialAdmin;
  MercadoPagoCheckoutService? _mercadoPagoCheckout;
  AdvertisingCampaignService? _advertisingCampaigns;
  AdCampaignAdminService? _adCampaignAdmin;
  AppAccessService? _appAccess;
  ContentAccessService? _contentAccess;

  FirestorePlatformRepositories get repositories =>
      _repos ??= FirestorePlatformRepositories();

  PlatformAuditService get audit =>
      _audit ??= PlatformAuditService(repositories.auditLogs);

  /// Gratuito vs premium (Firestore `app_access_config` + assinatura).
  AppAccessService get appAccess => _appAccess ??= AppAccessService(
        commercialAccess: commercialAccess,
      );

  /// Limites P0 — flashcards/questões no gratuito.
  ContentAccessService get contentAccess => _contentAccess ??=
      ContentAccessService(
        commercialAccess: commercialAccess,
        adminAccess: AdminAccessService.instance,
      );

  /// Acesso comercial do aluno (assinatura + entitlements).
  CommercialAccessService get commercialAccess => _commercialAccess ??=
      CommercialAccessService(
        subscriptionRepo: repositories.subscriptions,
        entitlementRepo: repositories.entitlements,
        planRepo: repositories.subscriptionPlans,
      );

  /// Gestão manual de assinaturas (Painel Mestre).
  CommercialAdminService get commercialAdmin => _commercialAdmin ??=
      CommercialAdminService(
        subscriptionRepo: repositories.subscriptions,
        entitlementRepo: repositories.entitlements,
        planRepo: repositories.subscriptionPlans,
        sellerRepo: repositories.sellers,
        affiliateRepo: repositories.affiliates,
        couponRepo: repositories.coupons,
        audit: audit,
      );

  /// Checkout Pro Mercado Pago (Cloud Function + url_launcher).
  MercadoPagoCheckoutService get mercadoPagoCheckout =>
      _mercadoPagoCheckout ??= MercadoPagoCheckoutService();

  /// Campanhas publicitárias (resolução + dashboard).
  AdvertisingCampaignService get advertisingCampaigns =>
      _advertisingCampaigns ??= AdvertisingCampaignService(
        campaignRepo: repositories.adCampaigns,
      );

  /// Administração de campanhas (Painel Mestre).
  AdCampaignAdminService get adCampaignAdmin => _adCampaignAdmin ??=
      AdCampaignAdminService(
        campaignRepo: repositories.adCampaigns,
        audit: audit,
      );

  /// RBAC — papéis, permissões dinâmicas e auditoria de acesso.
  RbacService get rbac => RbacService.instance;

  /// Métricas do painel administrativo mestre.
  MasterAdminDashboardService get masterAdminDashboard =>
      _masterDashboard ??= MasterAdminDashboardService(registry: this);

  /// Analytics — crescimento, conversão, retenção.
  AnalyticsDashboardService get analyticsDashboard =>
      _analyticsDashboard ??= AnalyticsDashboardService();

  PushCampaignAdminService get pushCampaignAdmin =>
      _pushCampaignAdmin ??= PushCampaignAdminService();

  /// Permite injeção em testes.
  void overrideForTesting(FirestorePlatformRepositories repos) {
    _repos = repos;
    _audit = PlatformAuditService(repos.auditLogs);
  }

  void reset() {
    _repos = null;
    _audit = null;
    _masterDashboard = null;
    _analyticsDashboard = null;
    _pushCampaignAdmin = null;
    _commercialAccess = null;
    _commercialAdmin = null;
    _mercadoPagoCheckout = null;
    _advertisingCampaigns = null;
    _adCampaignAdmin = null;
    _appAccess = null;
    _contentAccess = null;
  }
}
