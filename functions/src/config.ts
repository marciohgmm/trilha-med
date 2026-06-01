import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";
import { logSubscription } from "./subscription/subscriptionLogger";

export const mercadoPagoAccessToken = defineSecret("MERCADOPAGO_ACCESS_TOKEN");

/** Secret de assinatura do painel MP (Webhooks → secret signature). */
export const mercadoPagoWebhookSecret = defineSecret("MERCADOPAGO_WEBHOOK_SECRET");

/** Somente dev/emulador — nunca em produção. */
export const mercadoPagoWebhookSkipSignature = defineString(
  "MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE",
  {
    default: "false",
    description:
      "Se 'true', ignora validação x-signature (somente desenvolvimento)",
  }
);

export const mercadoPagoWebhookUrl = defineString("MERCADOPAGO_WEBHOOK_URL", {
  default: "",
  description:
    "URL pública HTTPS do mercadopagoWebhook (notification_url na preferência MP)",
});

/** Apenas desenvolvimento/emulador — nunca em produção. */
export const mercadoPagoAllowCheckoutWithoutWebhook = defineString(
  "MERCADOPAGO_ALLOW_CHECKOUT_WITHOUT_WEBHOOK",
  {
    default: "false",
    description:
      "Se 'true', permite checkout sem MERCADOPAGO_WEBHOOK_URL (somente dev)",
  }
);

export function getCheckoutUrls() {
  const success =
    process.env.APP_CHECKOUT_SUCCESS_URL ??
    "https://revalida-cards.web.app/checkout/success";
  const failure =
    process.env.APP_CHECKOUT_FAILURE_URL ??
    "https://revalida-cards.web.app/checkout/failure";
  const pending =
    process.env.APP_CHECKOUT_PENDING_URL ??
    "https://revalida-cards.web.app/checkout/pending";
  return { success, failure, pending };
}

export function getMercadoPagoWebhookUrl(): string {
  return mercadoPagoWebhookUrl.value().trim();
}

/**
 * P0-1: impede checkout sem IPN configurado (exceto flag explícita de dev).
 */
export function assertMercadoPagoCheckoutConfig(): string {
  const webhookUrl = getMercadoPagoWebhookUrl();
  const allowWithout =
    mercadoPagoAllowCheckoutWithoutWebhook.value().trim().toLowerCase() ===
    "true";

  let accessTokenPresent = false;
  try {
    accessTokenPresent = Boolean(mercadoPagoAccessToken.value()?.trim());
  } catch {
    accessTokenPresent = false;
  }

  logSubscription("checkout.config_validation", {
    hasWebhookUrl: webhookUrl.length > 0,
    allowCheckoutWithoutWebhook: allowWithout,
    hasAccessToken: accessTokenPresent,
  });

  if (!accessTokenPresent) {
    throw new HttpsError(
      "failed-precondition",
      "MERCADOPAGO_ACCESS_TOKEN não configurado. Configure o secret nas Cloud Functions."
    );
  }

  if (!webhookUrl && !allowWithout) {
    throw new HttpsError(
      "failed-precondition",
      "MERCADOPAGO_WEBHOOK_URL não configurada. " +
        "Defina a URL pública do webhook mercadopagoWebhook no painel Firebase " +
        "e no parâmetro MERCADOPAGO_WEBHOOK_URL antes de aceitar pagamentos."
    );
  }

  if (!webhookUrl && allowWithout) {
    logSubscription("checkout.webhook_url_skipped_dev", {});
  }

  return webhookUrl;
}
