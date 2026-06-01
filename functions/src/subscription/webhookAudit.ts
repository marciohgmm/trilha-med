import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";

const db = () => admin.firestore();

export type WebhookAuditAction =
  | "signature_validate"
  | "payment_process"
  | "payment_ignore";

export async function logMercadoPagoWebhookAudit(params: {
  paymentId?: string;
  action: WebhookAuditAction;
  success: boolean;
  reason: string;
  metadata?: Record<string, unknown>;
}): Promise<void> {
  try {
    await db().collection(COLLECTIONS.auditLogs).add({
      eventType: "webhook.mercadopago",
      actorUserId: "mercadopago_webhook",
      entityType: "payment",
      entityId: params.paymentId ?? "",
      metadata: {
        timestamp: new Date().toISOString(),
        paymentId: params.paymentId ?? "",
        action: params.action,
        success: params.success,
        reason: params.reason,
        ...params.metadata,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error(
      JSON.stringify({
        tag: "subscription",
        event: "webhook.audit_write_failed",
        message: err instanceof Error ? err.message : String(err),
      })
    );
  }
}
