export const COLLECTIONS = {
  subscriptionPlans: "platform_subscription_plans",
  subscriptions: "platform_subscriptions",
  payments: "platform_payments",
  coupons: "platform_coupons",
  sellers: "platform_sellers",
  affiliates: "platform_affiliates",
  auditLogs: "platform_audit_logs",
  rateLimits: "platform_rate_limits",
  analyticsEvents: "platform_analytics_events",
  pushCampaigns: "platform_push_campaigns",
  fcmUsers: "platform_fcm_users",
  liveEvents: "live_events",
  users: "users",
  entitlements: "platform_entitlements",
} as const;

export const ENTITLEMENT_KEYS = {
  premium: "premium",
  premiumLifetime: "premium_lifetime",
  courtesyAccess: "courtesy_access",
  betaTester: "beta_tester",
  sellerAccess: "seller_access",
} as const;

export const SUBSCRIPTION_STATUS = {
  active: "active",
  trialing: "trialing",
  pastDue: "past_due",
  canceled: "canceled",
  expired: "expired",
} as const;

export const PAYMENT_STATUS = {
  pending: "pending",
  processing: "processing",
  succeeded: "succeeded",
  failed: "failed",
  refunded: "refunded",
  canceled: "canceled",
} as const;

export const PAYMENT_PROVIDER = {
  mercadoPago: "mercado_pago",
  manual: "manual",
} as const;

export const GRANT_SOURCE = {
  mercadoPago: "mercado_pago",
  manual: "manual",
} as const;

export const BILLING_PERIOD_DAYS: Record<string, number> = {
  monthly: 30,
  yearly: 365,
};
