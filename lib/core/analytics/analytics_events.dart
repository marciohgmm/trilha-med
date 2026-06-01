/// Nomes de eventos Firebase Analytics / GA4 (snake_case, máx. 40 chars).
abstract final class AnalyticsEvents {
  // Auth & sessão
  static const login = 'login';
  static const signUp = 'sign_up';
  static const sessionStart = 'session_start';

  // Produto — estudo
  static const flashcardStudyStart = 'flashcard_study_start';
  static const questionsStudyStart = 'questions_study_start';
  static const simuladoStart = 'simulado_start';
  static const simuladoComplete = 'simulado_complete';
  static const osceLobbyOpen = 'osce_lobby_open';
  static const osceStationStart = 'osce_station_start';
  static const practicalPhaseOpen = 'practical_phase_open';
  static const liveEventJoin = 'live_event_join';

  // Comercial
  static const paywallView = 'paywall_view';
  static const plansView = 'plans_view';
  static const checkoutStart = 'checkout_start';
  static const purchaseApproved = 'purchase_approved';
  static const purchaseCancelled = 'purchase_cancelled';
  static const purchasePending = 'purchase_pending';
  static const couponApplied = 'coupon_applied';
  static const affiliateAttributed = 'affiliate_attributed';
  static const sellerAttributed = 'seller_attributed';

  // Navegação
  static const screenView = 'screen_view';
}

/// Chaves de parâmetros padronizados.
abstract final class AnalyticsParams {
  static const screenName = 'screen_name';
  static const feature = 'feature';
  static const materia = 'materia';
  static const subtema = 'subtema';
  static const simuladoId = 'simulado_id';
  static const questionCount = 'question_count';
  static const scorePercent = 'score_percent';
  static const roomId = 'room_id';
  static const eventId = 'event_id';
  static const modelId = 'model_id';
  static const entitlement = 'entitlement';
  static const planId = 'plan_id';
  static const billingPeriod = 'billing_period';
  static const paymentId = 'payment_id';
  static const amount = 'amount';
  static const currency = 'currency';
  static const couponCode = 'coupon_code';
  static const affiliateId = 'affiliate_id';
  static const sellerId = 'seller_id';
  static const method = 'method';
}
