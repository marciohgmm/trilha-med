/// Tipos de notificação push (data payload `type`).
abstract final class PushNotificationType {
  static const flashcardReview = 'flashcard_review';
  static const cronogramaOverdue = 'cronograma_overdue';
  static const simuladoAvailable = 'simulado_available';
  static const liveEvent = 'live_event';
  static const subscriptionRenewal = 'subscription_renewal';
  static const promotional = 'promotional';
  static const adminBroadcast = 'admin_broadcast';

  static const all = [
    flashcardReview,
    cronogramaOverdue,
    simuladoAvailable,
    liveEvent,
    subscriptionRenewal,
    promotional,
    adminBroadcast,
  ];

  static String label(String type) => switch (type) {
        flashcardReview => 'Revisão de flashcards',
        cronogramaOverdue => 'Cronograma atrasado',
        simuladoAvailable => 'Simulados disponíveis',
        liveEvent => 'Eventos ao vivo',
        subscriptionRenewal => 'Renovação de assinatura',
        promotional => 'Campanhas promocionais',
        adminBroadcast => 'Comunicados administrativos',
        _ => type,
      };
}

/// Segmentação de envio (Painel Mestre / campanhas).
abstract final class PushAudienceSegment {
  static const all = 'all';
  static const premium = 'premium';
  static const free = 'free';
  static const active7d = 'active_7d';
  static const subscriptionExpiring = 'subscription_expiring';
  static const liveEventAudience = 'live_event_audience';

  static const options = [
    (all, 'Todos com push ativo'),
    (premium, 'Assinantes Premium'),
    (free, 'Usuários gratuitos'),
    (active7d, 'Ativos nos últimos 7 dias'),
    (subscriptionExpiring, 'Renovação em até 7 dias'),
    (liveEventAudience, 'Interessados em evento (ID)'),
  ];
}

/// Chaves de preferência do usuário (`users.notificationPrefs`).
abstract final class PushPreferenceKeys {
  static const flashcardReview = PushNotificationType.flashcardReview;
  static const cronogramaOverdue = PushNotificationType.cronogramaOverdue;
  static const simuladoAvailable = PushNotificationType.simuladoAvailable;
  static const liveEvent = PushNotificationType.liveEvent;
  static const subscriptionRenewal = PushNotificationType.subscriptionRenewal;
  static const promotional = PushNotificationType.promotional;
  static const adminBroadcast = PushNotificationType.adminBroadcast;
}
