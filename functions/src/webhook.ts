import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  getMercadoPagoWebhookUrl,
  mercadoPagoAccessToken,
  mercadoPagoWebhookSecret,
  mercadoPagoWebhookSkipSignature,
} from "./config";
import {
  auditMercadoPagoWebhookConfig,
  shouldSkipMercadoPagoWebhookSignature,
} from "./mercadoPagoRuntimeConfig";
import { expireDueSubscriptions } from "./subscriptionService";
import { processMercadoPagoPaymentById } from "./subscription/paymentProcessor";
import { validateMercadoPagoWebhookSignature } from "./subscription/mercadoPagoWebhookAuth";
import { logMercadoPagoWebhookAudit } from "./subscription/webhookAudit";
import { logSubscription, logSubscriptionError } from "./subscription/subscriptionLogger";

function extractPaymentIdFromWebhook(req: {
  query: Record<string, unknown>;
  body?: unknown;
}): string | undefined {
  const q = req.query;
  const fromQuery =
    (q["data.id"] as string) ?? (q.id as string) ?? undefined;
  if (fromQuery) return String(fromQuery);

  const body = req.body as Record<string, unknown> | undefined;
  const data = body?.data as Record<string, unknown> | undefined;
  if (data?.id != null) return String(data.id);
  return undefined;
}

function headerString(
  headers: Record<string, unknown>,
  name: string
): string | undefined {
  const lower = name.toLowerCase();
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() !== lower) continue;
    if (Array.isArray(value)) return value[0]?.toString();
    return value?.toString();
  }
  return undefined;
}

/** Webhook IPN Mercado Pago — valida assinatura, consulta API MP, atualiza Firestore. */
export const mercadopagoWebhook = onRequest(
  {
    secrets: [mercadoPagoAccessToken, mercadoPagoWebhookSecret],
    region: "southamerica-east1",
  },
  async (req, res) => {
    if (req.method !== "POST" && req.method !== "GET") {
      res.status(405).send("Method not allowed");
      return;
    }

    const skipParamValue = mercadoPagoWebhookSkipSignature.value();
    auditMercadoPagoWebhookConfig({
      webhookUrl: getMercadoPagoWebhookUrl(),
      skipParamValue,
    });

    const paymentIdFromQuery = extractPaymentIdFromWebhook(req);

    try {
      const topic =
        (req.query.topic as string) ??
        (req.query.type as string) ??
        (req.body as Record<string, unknown> | undefined)?.type ??
        (req.body as Record<string, unknown> | undefined)?.action;

      logSubscription("webhook.received", {
        method: req.method,
        topic: topic ?? null,
        hasPaymentId: Boolean(paymentIdFromQuery),
      });

      if (!paymentIdFromQuery) {
        res.status(200).send("ok");
        return;
      }

      const skipSignature = shouldSkipMercadoPagoWebhookSignature(skipParamValue);

      if (!skipSignature) {
        const xSignature = headerString(
          req.headers as Record<string, unknown>,
          "x-signature"
        );
        const xRequestId = headerString(
          req.headers as Record<string, unknown>,
          "x-request-id"
        );

        const validation = validateMercadoPagoWebhookSignature({
          secret: mercadoPagoWebhookSecret.value(),
          xSignature,
          xRequestId,
          dataId: paymentIdFromQuery,
        });

        if (!validation.valid) {
          logSubscription("webhook.signature_rejected", {
            paymentId: paymentIdFromQuery,
            reason: validation.reason,
          });
          await logMercadoPagoWebhookAudit({
            paymentId: paymentIdFromQuery,
            action: "signature_validate",
            success: false,
            reason: validation.reason,
            metadata: {
              requestId: validation.requestId,
              ts: validation.ts,
            },
          });
          res.status(401).send("invalid signature");
          return;
        }

        await logMercadoPagoWebhookAudit({
          paymentId: paymentIdFromQuery,
          action: "signature_validate",
          success: true,
          reason: "ok",
          metadata: {
            requestId: validation.requestId,
            ts: validation.ts,
          },
        });
      } else {
        logSubscription("webhook.signature_skipped_dev", {
          paymentId: paymentIdFromQuery,
        });
      }

      if (
        topic &&
        !String(topic).includes("payment") &&
        topic !== "payment.created" &&
        topic !== "payment.updated"
      ) {
        await logMercadoPagoWebhookAudit({
          paymentId: paymentIdFromQuery,
          action: "payment_ignore",
          success: true,
          reason: `topic_ignored:${topic}`,
        });
        res.status(200).send("ignored");
        return;
      }

      const accessToken = mercadoPagoAccessToken.value();
      const outcome = await processMercadoPagoPaymentById(
        accessToken,
        String(paymentIdFromQuery),
        "webhook"
      );

      if (outcome === "mp_not_found") {
        await logMercadoPagoWebhookAudit({
          paymentId: paymentIdFromQuery,
          action: "payment_process",
          success: false,
          reason: "mp_payment_not_found",
        });
        res.status(404).send("payment not found");
        return;
      }
      if (outcome === "not_found") {
        await logMercadoPagoWebhookAudit({
          paymentId: paymentIdFromQuery,
          action: "payment_process",
          success: false,
          reason: "local_payment_not_found",
        });
        res.status(404).send("local payment not found");
        return;
      }

      await logMercadoPagoWebhookAudit({
        paymentId: paymentIdFromQuery,
        action: "payment_process",
        success: outcome === "ok",
        reason: outcome,
      });

      res.status(200).send("ok");
    } catch (err) {
      logSubscriptionError("webhook.error", err, {
        paymentId: paymentIdFromQuery,
      });
      await logMercadoPagoWebhookAudit({
        paymentId: paymentIdFromQuery,
        action: "payment_process",
        success: false,
        reason: err instanceof Error ? err.message : "internal_error",
      });
      res.status(500).send("error");
    }
  }
);

/** Expira assinaturas vencidas diariamente às 06:00 BRT. */
export const expireSubscriptionsScheduled = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const count = await expireDueSubscriptions();
    logSubscription("subscriptions.expired_batch", { count });
  }
);
