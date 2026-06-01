import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";

const db = () => admin.firestore();

export async function logRateLimitAudit(params: {
  action: string;
  uid?: string;
  blocked: boolean;
  reason: string;
  subjectKey?: string;
  ipHash?: string;
}): Promise<void> {
  const payload = {
    tag: "rate_limit",
    timestamp: new Date().toISOString(),
    uid: params.uid ?? null,
    action: params.action,
    blocked: params.blocked,
    reason: params.reason,
    subjectKey: params.subjectKey,
    ipHash: params.ipHash,
  };

  console.log(JSON.stringify(payload));

  if (!params.blocked) return;

  try {
    await db().collection(COLLECTIONS.auditLogs).add({
      eventType: "rate_limit.blocked",
      actorUserId: params.uid ?? "anonymous",
      entityType: "rate_limit",
      entityId: params.action,
      metadata: payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error(
      JSON.stringify({
        tag: "rate_limit",
        event: "audit_write_failed",
        message: err instanceof Error ? err.message : String(err),
      })
    );
  }
}
