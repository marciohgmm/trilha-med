export const PUSH_TYPES = {
  flashcardReview: "flashcard_review",
  cronogramaOverdue: "cronograma_overdue",
  simuladoAvailable: "simulado_available",
  liveEvent: "live_event",
  subscriptionRenewal: "subscription_renewal",
  promotional: "promotional",
  adminBroadcast: "admin_broadcast",
} as const;

export type PushType = (typeof PUSH_TYPES)[keyof typeof PUSH_TYPES];

export const PUSH_SEGMENTS = {
  all: "all",
  premium: "premium",
  free: "free",
  active7d: "active_7d",
  subscriptionExpiring: "subscription_expiring",
  liveEventAudience: "live_event_audience",
} as const;

/** Público de push automático/callable de Live Events (campo `live_events.pushAudience`). */
export const LIVE_EVENT_PUSH_AUDIENCE = {
  /** Apenas inscritos em `participants` + host. Padrão. */
  participants: "participants",
  /** Divulgação explícita: usuários ativos (7d) com pref `live_event` — nunca `all`. */
  platformPublic: "platform_public",
} as const;

export type LiveEventPushAudience =
  (typeof LIVE_EVENT_PUSH_AUDIENCE)[keyof typeof LIVE_EVENT_PUSH_AUDIENCE];
