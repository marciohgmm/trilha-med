import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "./constants";
import { appCheckCallableOptions } from "./callableOptions";
import { assertRateLimitForCallable } from "./rateLimit/assertRateLimit";
import { RATE_LIMIT_ACTIONS } from "./rateLimit/rateLimitConfig";

const db = () => admin.firestore();

const CONFIRMATION_PHRASE = "EXCLUIR";
const BATCH_SIZE = 400;

async function deleteCollection(
  col: admin.firestore.CollectionReference
): Promise<number> {
  let deleted = 0;
  while (true) {
    const snap = await col.limit(BATCH_SIZE).get();
    if (snap.empty) break;
    const batch = db().batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snap.size;
    if (snap.size < BATCH_SIZE) break;
  }
  return deleted;
}

async function deleteUserSubcollections(userId: string): Promise<number> {
  const userRef = db().collection(COLLECTIONS.users).doc(userId);
  const subcols = await userRef.listCollections();
  let total = 0;
  for (const sub of subcols) {
    total += await deleteCollection(sub);
  }
  return total;
}

async function deleteAnalyticsEventsForUser(userId: string): Promise<void> {
  let rounds = 0;
  while (rounds < 10) {
    const snap = await db()
      .collection(COLLECTIONS.analyticsEvents)
      .where("userId", "==", userId)
      .limit(BATCH_SIZE)
      .get();
    if (snap.empty) break;
    const batch = db().batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    rounds++;
  }
}

/** Eliminação de conta (LGPD) — preserva pagamentos e auditoria financeira. */
export const deleteMyAccount = onCall(
  appCheckCallableOptions(),
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login necessário.");
    }

    const confirmation = (request.data?.confirmation as string)?.trim().toUpperCase();
    if (confirmation !== CONFIRMATION_PHRASE) {
      throw new HttpsError(
        "invalid-argument",
        "Confirmação inválida. Digite EXCLUIR."
      );
    }

    await assertRateLimitForCallable(request, RATE_LIMIT_ACTIONS.deleteAccount);

    const uid = request.auth.uid;
    const anonymizedId = `deleted_${uid.substring(0, 8)}`;

    await db().collection(COLLECTIONS.auditLogs).add({
      eventType: "account.deletion_requested",
      actorUserId: uid,
      targetUserId: uid,
      entityType: "user",
      entityId: uid,
      metadata: {
        timestamp: new Date().toISOString(),
        action: "delete_account",
        success: true,
        reason: "user_confirmed",
        anonymizedId,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const subDocsDeleted = await deleteUserSubcollections(uid);

    await deleteAnalyticsEventsForUser(uid);

    try {
      await db().collection(COLLECTIONS.fcmUsers).doc(uid).delete();
    } catch {
      /* optional */
    }

    try {
      await db().collection("admins").doc(uid).delete();
    } catch {
      /* optional */
    }

  // Preserva platform_payments / platform_subscriptions (obrigação legal).
  // Remove PII vinculado ao doc raiz do usuário.
    await db().collection(COLLECTIONS.users).doc(uid).delete();

    try {
      await admin.auth().deleteUser(uid);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!message.includes("user-not-found")) {
        throw new HttpsError("internal", `Falha ao remover Auth: ${message}`);
      }
    }

    await db().collection(COLLECTIONS.auditLogs).add({
      eventType: "account.deletion_completed",
      actorUserId: "system",
      targetUserId: anonymizedId,
      entityType: "user",
      entityId: uid,
      metadata: {
        timestamp: new Date().toISOString(),
        action: "delete_account",
        success: true,
        reason: "completed",
        subDocsDeleted,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, subDocsDeleted };
  }
);
