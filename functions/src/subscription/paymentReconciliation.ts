import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { mercadoPagoAccessToken } from "../config";
import { COLLECTIONS, PAYMENT_STATUS } from "../constants";
import { listPaymentsToReconcileForUser } from "../subscriptionService";
import { reconcileLocalPaymentDoc } from "./paymentProcessor";
import { logSubscription } from "./subscriptionLogger";
import { appCheckCallableOptions } from "../callableOptions";
import { assertRateLimitForCallable } from "../rateLimit/assertRateLimit";
import { RATE_LIMIT_ACTIONS } from "../rateLimit/rateLimitConfig";

const db = () => admin.firestore();

const RECONCILE_STATUSES = [
  PAYMENT_STATUS.pending,
  PAYMENT_STATUS.processing,
];

/** P0-4: reconcilia pagamentos pendentes/antigos sem depender só do IPN. */
export const reconcileMercadoPagoPaymentsScheduled = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "southamerica-east1",
    secrets: [mercadoPagoAccessToken],
  },
  async () => {
    const accessToken = mercadoPagoAccessToken.value();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 5 * 60 * 1000
    );

    let processed = 0;
    for (const status of RECONCILE_STATUSES) {
      const snap = await db()
        .collection(COLLECTIONS.payments)
        .where("status", "==", status)
        .where("updatedAt", "<", cutoff)
        .limit(40)
        .get();

      for (const doc of snap.docs) {
        await reconcileLocalPaymentDoc(accessToken, doc.id, "reconcile_scheduled");
        processed++;
      }
    }

    logSubscription("reconcile.scheduled_complete", { processed });
  }
);

/** Callable: usuário autenticado reconcilia seus pagamentos recentes (pós-checkout). */
export const reconcileMyMercadoPagoPayments = onCall(
  appCheckCallableOptions(
    { secrets: [mercadoPagoAccessToken] },
    { consumeAppCheckToken: true },
  ),
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login necessário.");
    }

    await assertRateLimitForCallable(request, RATE_LIMIT_ACTIONS.reconcile);

    const userId = request.auth.uid;
    const paymentIds = await listPaymentsToReconcileForUser(userId, 5);
    const accessToken = mercadoPagoAccessToken.value();

    logSubscription("reconcile.callable_start", {
      userId,
      paymentCount: paymentIds.length,
    });

    let repaired = 0;
    for (const paymentId of paymentIds) {
      await reconcileLocalPaymentDoc(accessToken, paymentId, "reconcile_callable");
      repaired++;
    }

    return {
      reconciled: repaired,
      paymentIds,
    };
  }
);
