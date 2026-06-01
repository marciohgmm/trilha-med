/** Identificadores de ação (gravados em platform_rate_limits e auditoria). */
export const RATE_LIMIT_ACTIONS = {
  checkout: "checkout.mercado_pago",
  reconcile: "payment.reconcile_my",
  pushCampaign: "push.campaign_create",
  notifyLiveBroadcast: "push.live_broadcast",
  registerFcm: "fcm.register_token",
  deleteAccount: "account.delete",
  authLogin: "auth.login",
  authSignUp: "auth.signup",
  authResetPassword: "auth.reset_password",
} as const;

export type RateLimitScope = "uid" | "ip" | "email";

export type RateLimitRule = {
  scope: RateLimitScope;
  maxRequests: number;
  windowMs: number;
};

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** Limites documentados (Etapa C). */
export const RATE_LIMIT_RULES: Record<string, RateLimitRule[]> = {
  [RATE_LIMIT_ACTIONS.checkout]: [
    { scope: "uid", maxRequests: 3, windowMs: HOUR },
    { scope: "ip", maxRequests: 6, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.reconcile]: [
    { scope: "uid", maxRequests: 10, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.pushCampaign]: [
    { scope: "uid", maxRequests: 20, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.notifyLiveBroadcast]: [
    { scope: "uid", maxRequests: 60, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.registerFcm]: [
    { scope: "uid", maxRequests: 60, windowMs: HOUR },
    { scope: "ip", maxRequests: 120, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.deleteAccount]: [
    { scope: "uid", maxRequests: 2, windowMs: DAY },
  ],
  [RATE_LIMIT_ACTIONS.authLogin]: [
    { scope: "email", maxRequests: 20, windowMs: HOUR },
    { scope: "ip", maxRequests: 40, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.authSignUp]: [
    { scope: "email", maxRequests: 10, windowMs: HOUR },
    { scope: "ip", maxRequests: 20, windowMs: HOUR },
  ],
  [RATE_LIMIT_ACTIONS.authResetPassword]: [
    { scope: "email", maxRequests: 5, windowMs: HOUR },
    { scope: "ip", maxRequests: 15, windowMs: HOUR },
  ],
};

export const RATE_LIMIT_USER_MESSAGE =
  "Muitas tentativas. Aguarde alguns minutos e tente novamente.";
