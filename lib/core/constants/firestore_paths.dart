/// Caminhos e nomes de coleções Firestore (existentes + plataforma).
///
/// Coleções legadas: continue usando os serviços atuais.
/// Coleções [platform*]: módulo de crescimento (`lib/domain/platform`).
class FirestorePaths {
  FirestorePaths._();

  // ---------------------------------------------------------------------------
  // Legado (referência — não migrar nesta fase)
  // ---------------------------------------------------------------------------
  static const users = 'users';

  /// Coleção legada (F1) — não escrever. Leitura só para migração.
  @Deprecated('Legado F1. Use [users]. Ver docs/F1_USERS_USUARIOS.md.')
  static const usuarios = 'usuarios';

  /// `users/{userId}/progresso/{cardId}` — flashcards e cronograma.
  static const userProgressSubcollection = 'progresso';

  static const userProgressoQuestoesSubcollection = 'progresso_questoes';
  static const userSimuladosHistoricoSubcollection = 'simulados_historico';
  static const userQuestaoReportsSubcollection = 'questao_reports';
  static const flashcards = 'flashcards';

  /// Agregação por matéria para a Home (`total` de cards). Mantida por admin/CRUD.
  static const flashcardsMateriaStats = 'flashcards_materia_stats';

  /// Pares únicos matéria/subtema para cronograma (~S docs, não N flashcards).
  static const flashcardsSubtemaCatalog = 'flashcards_subtema_catalog';

  /// Agregação por matéria para questões (lista / simulado).
  static const questoesMateriaStats = 'questoes_materia_stats';

  /// Pares matéria/subtema para questões (navegação sem varrer `questoes`).
  static const questoesSubtemaCatalog = 'questoes_subtema_catalog';

  static const questoes = 'questoes';
  static const admins = 'admins';
  static const notificacoesAdmin = 'notificacoes_admin';
  static const globalMessages = 'global_messages';
  static const osceCases = 'osce_cases';
  static const osceRooms = 'osce_rooms';
  static const osceEvaluations = 'osce_evaluations';
  static const liveEvents = 'live_events';
  static const practicalPhaseModels = 'practical_phase_models';
  static const practicalPhaseModules = 'practical_phase_modules';
  static const revalidaSimulations = 'revalida_simulations';

  // ---------------------------------------------------------------------------
  // Plataforma (crescimento)
  // ---------------------------------------------------------------------------
  static const platformSubscriptionPlans = 'platform_subscription_plans';
  static const platformSubscriptions = 'platform_subscriptions';
  static const platformPayments = 'platform_payments';
  static const platformSellers = 'platform_sellers';
  static const platformAffiliates = 'platform_affiliates';
  static const platformCoupons = 'platform_coupons';
  static const platformPartnerships = 'platform_partnerships';
  static const platformAdvertisements = 'platform_advertisements';
  static const platformAdCampaigns = 'platform_ad_campaigns';
  static const platformAuditLogs = 'platform_audit_logs';
  static const platformAnalyticsEvents = 'platform_analytics_events';

  /// Agregação diária para dashboard admin (permanente).
  static const platformAnalyticsDaily = 'platform_analytics_daily';
  static const platformPushCampaigns = 'platform_push_campaigns';
  static const platformFcmUsers = 'platform_fcm_users';
  static const platformRbacRoles = 'platform_rbac_roles';
  static const platformRbacPermissions = 'platform_rbac_permissions';
  static const platformFeatureFlags = 'platform_feature_flags';

  /// Configuração gratuito vs premium: `app_access_config/plans`
  static const appAccessConfig = 'app_access_config';

  /// Subcoleção: `users/{userId}/platform_notifications/{id}`
  static const userPlatformNotifications = 'platform_notifications';

  /// Subcoleção: `users/{userId}/platform_entitlements/{id}`
  static const userPlatformEntitlements = 'platform_entitlements';

  /// Perfil público (S1): `users/{userId}/public_profile/profile`
  static const userPublicProfile = 'public_profile';
  static const userPublicProfileDocId = 'profile';

  /// Aceites legais (LGPD): `users/{userId}/legal_acceptances/{id}`
  static const legalAcceptances = 'legal_acceptances';

  /// P0 — uso de cota gratuito: `users/{userId}/access_usage/stats`
  static const userAccessUsage = 'access_usage';

  static String userAccessUsageStatsPath(String userId) =>
      '$users/$userId/$userAccessUsage/stats';

  static String userAccessUsageFlashcardItemPath(
    String userId,
    String cardId,
  ) =>
      '$users/$userId/$userAccessUsage/flashcards/items/$cardId';

  static String userAccessUsageQuestionItemPath(
    String userId,
    String questionId,
  ) =>
      '$users/$userId/$userAccessUsage/questions/items/$questionId';
}
