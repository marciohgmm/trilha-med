import { logSubscription, logSubscriptionError } from "./subscription/subscriptionLogger";

/** Projeto Firebase de produção. */
export const FIREBASE_PRODUCTION_PROJECT_ID = "revalida-cards";

export const MERCADOPAGO_WEBHOOK_FUNCTION_NAME = "mercadopagoWebhook";

export const MERCADOPAGO_WEBHOOK_REGION = "southamerica-east1";

/**
 * URL de referência (Gen2 esperada) — auditoria em log; NÃO substitui confirmação pós-deploy.
 * Defina MERCADOPAGO_WEBHOOK_URL e o painel MP com a URL publicada:
 * `firebase functions:list --project revalida-cards`
 */
export const OFFICIAL_MERCADOPAGO_WEBHOOK_URL =
  `https://${MERCADOPAGO_WEBHOOK_REGION}-${FIREBASE_PRODUCTION_PROJECT_ID}.cloudfunctions.net/${MERCADOPAGO_WEBHOOK_FUNCTION_NAME}`;

export function isFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

export function isFirebaseProduction(): boolean {
  const project =
    process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "";
  return project === FIREBASE_PRODUCTION_PROJECT_ID && !isFunctionsEmulator();
}

function parseSkipFlag(skipParamValue: string): boolean {
  return skipParamValue.trim().toLowerCase() === "true";
}

/**
 * Em produção a assinatura x-signature é sempre exigida, mesmo se
 * MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true estiver definido por engano.
 */
export function shouldSkipMercadoPagoWebhookSignature(
  skipParamValue: string
): boolean {
  if (!parseSkipFlag(skipParamValue)) {
    return false;
  }
  if (isFirebaseProduction()) {
    logSubscriptionError(
      "webhook.config_unsafe_skip_ignored",
      new Error(
        "MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true ignorado em produção — assinatura obrigatória"
      ),
      { project: FIREBASE_PRODUCTION_PROJECT_ID }
    );
    return false;
  }
  if (isFunctionsEmulator()) {
    logSubscription("webhook.signature_skip_emulator", {});
    return true;
  }
  logSubscription("webhook.signature_skip_non_production", {
    project: process.env.GCLOUD_PROJECT ?? "unknown",
  });
  return true;
}

export function normalizeWebhookUrl(url: string): string {
  return url.trim().replace(/\/+$/, "");
}

export function webhookUrlLooksValid(url: string): boolean {
  const normalized = normalizeWebhookUrl(url);
  if (!normalized.startsWith("https://")) return false;
  return normalized.endsWith(`/${MERCADOPAGO_WEBHOOK_FUNCTION_NAME}`);
}

/**
 * Alertas de configuração (logs) — não altera lógica de pagamento.
 */
export function auditMercadoPagoWebhookConfig(params: {
  webhookUrl: string;
  skipParamValue: string;
}): void {
  const configuredUrl = normalizeWebhookUrl(params.webhookUrl);
  const skipRequested = parseSkipFlag(params.skipParamValue);
  const production = isFirebaseProduction();

  logSubscription("webhook.config_audit", {
    production,
    emulator: isFunctionsEmulator(),
    hasWebhookUrl: configuredUrl.length > 0,
    skipSignatureRequested: skipRequested,
    skipSignatureEffective: shouldSkipMercadoPagoWebhookSignature(
      params.skipParamValue
    ),
    officialUrl: OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
    configuredUrl: configuredUrl || null,
    matchesOfficialCanonical:
      configuredUrl.length > 0 &&
      configuredUrl === OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
  });

  if (production && !configuredUrl) {
    logSubscriptionError(
      "webhook.config_missing_url",
      new Error("MERCADOPAGO_WEBHOOK_URL ausente em produção"),
      { hint: `Defina: ${OFFICIAL_MERCADOPAGO_WEBHOOK_URL}` }
    );
  }

  if (configuredUrl && !webhookUrlLooksValid(configuredUrl)) {
    logSubscriptionError(
      "webhook.config_invalid_url_shape",
      new Error("MERCADOPAGO_WEBHOOK_URL não termina com /mercadopagoWebhook"),
      { configuredUrl }
    );
  }

  if (
    configuredUrl &&
    production &&
    configuredUrl !== OFFICIAL_MERCADOPAGO_WEBHOOK_URL
  ) {
    logSubscriptionError(
      "webhook.config_url_mismatch_canonical",
      new Error(
        "MERCADOPAGO_WEBHOOK_URL difere da URL canônica documentada — alinhe Firebase, MP e checkout"
      ),
      {
        configuredUrl,
        officialUrl: OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
      }
    );
  }

  if (production && skipRequested) {
    logSubscriptionError(
      "webhook.config_unsafe_skip_in_production",
      new Error(
        "MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true em produção — será ignorado; remova o param"
      ),
      {}
    );
  }
}

export function warnCheckoutWebhookUrlIfInconsistent(webhookUrl: string): void {
  const normalized = normalizeWebhookUrl(webhookUrl);
  if (!normalized) return;

  if (!webhookUrlLooksValid(normalized)) {
    logSubscriptionError(
      "checkout.webhook_url_invalid_shape",
      new Error("notification_url deve apontar para mercadopagoWebhook"),
      { webhookUrl: normalized }
    );
  }

  if (
    isFirebaseProduction() &&
    normalized !== OFFICIAL_MERCADOPAGO_WEBHOOK_URL
  ) {
    logSubscription("checkout.webhook_url_differs_from_canonical", {
      notificationUrl: normalized,
      officialUrl: OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
    });
  }
}
