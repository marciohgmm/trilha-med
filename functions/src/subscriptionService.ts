import * as admin from "firebase-admin";
import {
  BILLING_PERIOD_DAYS,
  COLLECTIONS,
  ENTITLEMENT_KEYS,
  GRANT_SOURCE,
  PAYMENT_STATUS,
  SUBSCRIPTION_STATUS,
} from "./constants";
import { logSubscription, logSubscriptionError } from "./subscription/subscriptionLogger";
import { shouldRevokePremiumEntitlementOnPaymentReject } from "./subscription/subscriptionRevokePolicy";

const db = () => admin.firestore();

export interface ActivatePremiumParams {
  userId: string;
  planId: string;
  billingPeriod: "monthly" | "yearly";
  paymentId: string;
  providerPaymentId: string;
  amount: number;
  sellerId?: string;
  affiliateId?: string;
  couponId?: string;
}

/**
 * Ativa ou repara assinatura premium após pagamento aprovado.
 * Idempotente: se payment já succeeded, garante subscription + entitlement consistentes.
 */
export async function activatePremiumFromPayment(
  params: ActivatePremiumParams
): Promise<{ subscriptionId: string }> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(params.paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new Error(`Payment ${params.paymentId} not found`);
  }
  const paymentData = paymentSnap.data()!;

  if (paymentData.status === PAYMENT_STATUS.succeeded) {
    const existingSubId = (paymentData.subscriptionId as string) ?? "";
    if (existingSubId) {
      await ensureActivationComplete({
        userId: params.userId,
        planId: params.planId,
        billingPeriod: params.billingPeriod,
        paymentId: params.paymentId,
        subscriptionId: existingSubId,
        providerPaymentId: params.providerPaymentId,
        amount: params.amount,
        sellerId: params.sellerId,
        affiliateId: params.affiliateId,
        couponId: params.couponId,
      });
      logSubscription("payment.activate_idempotent_repair", {
        paymentId: params.paymentId,
        subscriptionId: existingSubId,
      });
      return { subscriptionId: existingSubId };
    }
  }

  const now = admin.firestore.Timestamp.now();
  const nowDate = now.toDate();
  const periodDays = BILLING_PERIOD_DAYS[params.billingPeriod] ?? 30;

  let subscriptionId = paymentData.subscriptionId as string | undefined;
  let periodEnd = new Date(nowDate);
  periodEnd.setDate(periodEnd.getDate() + periodDays);

  if (subscriptionId) {
    const subRef = db().collection(COLLECTIONS.subscriptions).doc(subscriptionId);
    const subSnap = await subRef.get();
    if (subSnap.exists) {
      const subData = subSnap.data()!;
      const existingEnd = subData.currentPeriodEnd?.toDate?.() as Date | undefined;
      if (
        existingEnd &&
        existingEnd > nowDate &&
        subData.status === SUBSCRIPTION_STATUS.active
      ) {
        periodEnd = new Date(existingEnd);
        periodEnd.setDate(periodEnd.getDate() + periodDays);
      }
      await subRef.update({
        status: SUBSCRIPTION_STATUS.active,
        planId: params.planId,
        currentPeriodStart: now,
        currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
        sellerId: params.sellerId ?? subData.sellerId ?? null,
        affiliateId: params.affiliateId ?? subData.affiliateId ?? null,
        couponId: params.couponId ?? subData.couponId ?? null,
        grantSource: GRANT_SOURCE.mercadoPago,
        externalProviderId: params.providerPaymentId,
        updatedAt: now,
      });
    } else {
      subscriptionId = undefined;
    }
  }

  if (!subscriptionId) {
    const subRef = db().collection(COLLECTIONS.subscriptions).doc();
    subscriptionId = subRef.id;
    await subRef.set({
      userId: params.userId,
      planId: params.planId,
      status: SUBSCRIPTION_STATUS.active,
      currentPeriodStart: now,
      currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
      sellerId: params.sellerId ?? null,
      affiliateId: params.affiliateId ?? null,
      couponId: params.couponId ?? null,
      grantSource: GRANT_SOURCE.mercadoPago,
      externalProviderId: params.providerPaymentId,
      createdAt: now,
      updatedAt: now,
    });
  }

  await paymentRef.update({
    status: PAYMENT_STATUS.succeeded,
    providerPaymentId: params.providerPaymentId,
    subscriptionId,
    amount: params.amount,
    paidAt: now,
    updatedAt: now,
  });

  await ensureActivationComplete({
    userId: params.userId,
    planId: params.planId,
    billingPeriod: params.billingPeriod,
    paymentId: params.paymentId,
    subscriptionId: subscriptionId!,
    providerPaymentId: params.providerPaymentId,
    amount: params.amount,
    sellerId: params.sellerId,
    affiliateId: params.affiliateId,
    couponId: params.couponId,
  });

  await db().collection(COLLECTIONS.auditLogs).add({
    eventType: "payment.succeeded",
    actorUserId: "mercadopago_webhook",
    targetUserId: params.userId,
    entityType: "payment",
    entityId: params.paymentId,
    metadata: { providerPaymentId: params.providerPaymentId },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { subscriptionId: subscriptionId! };
}

interface EnsureActivationParams {
  userId: string;
  planId: string;
  billingPeriod: "monthly" | "yearly";
  paymentId: string;
  subscriptionId: string;
  providerPaymentId: string;
  amount: number;
  sellerId?: string;
  affiliateId?: string;
  couponId?: string;
}

/** Garante payment succeeded + subscription ativa + entitlement premium alinhados. */
async function ensureActivationComplete(
  params: EnsureActivationParams
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(params.paymentId);
  const subRef = db()
    .collection(COLLECTIONS.subscriptions)
    .doc(params.subscriptionId);

  const [paymentSnap, subSnap] = await Promise.all([
    paymentRef.get(),
    subRef.get(),
  ]);

  if (!subSnap.exists) {
    logSubscriptionError(
      "ensure.missing_subscription",
      new Error("subscription doc missing"),
      {
        paymentId: params.paymentId,
        subscriptionId: params.subscriptionId,
      }
    );
    const now = admin.firestore.Timestamp.now();
    const periodDays = BILLING_PERIOD_DAYS[params.billingPeriod] ?? 30;
    const periodEnd = new Date(now.toDate());
    periodEnd.setDate(periodEnd.getDate() + periodDays);
    await subRef.set({
      userId: params.userId,
      planId: params.planId,
      status: SUBSCRIPTION_STATUS.active,
      currentPeriodStart: now,
      currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
      sellerId: params.sellerId ?? null,
      affiliateId: params.affiliateId ?? null,
      couponId: params.couponId ?? null,
      grantSource: GRANT_SOURCE.mercadoPago,
      externalProviderId: params.providerPaymentId,
      createdAt: now,
      updatedAt: now,
    });
  }

  const subData = (await subRef.get()).data()!;
  const periodEndTs = subData.currentPeriodEnd as admin.firestore.Timestamp;
  const periodEnd = periodEndTs?.toDate?.() ?? new Date();

  await upsertPremiumEntitlement({
    userId: params.userId,
    subscriptionId: params.subscriptionId,
    expiresAt: periodEnd,
    sellerId: params.sellerId,
    affiliateId: params.affiliateId,
    couponId: params.couponId,
  });

  const payData = paymentSnap.data() ?? {};
  const patch: Record<string, unknown> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (payData.status !== PAYMENT_STATUS.succeeded) {
    patch.status = PAYMENT_STATUS.succeeded;
    patch.paidAt = admin.firestore.FieldValue.serverTimestamp();
  }
  if (!payData.subscriptionId) {
    patch.subscriptionId = params.subscriptionId;
  }
  if (!payData.providerPaymentId) {
    patch.providerPaymentId = params.providerPaymentId;
  }
  if (Object.keys(patch).length > 1) {
    await paymentRef.update(patch);
    logSubscription("ensure.payment_repaired", {
      paymentId: params.paymentId,
      patch: Object.keys(patch),
    });
  }

  const entOk = await hasActivePremiumEntitlementForSubscription(
    params.userId,
    params.subscriptionId
  );
  if (!entOk) {
    logSubscriptionError(
      "ensure.entitlement_still_missing",
      new Error("entitlement repair failed"),
      { paymentId: params.paymentId, userId: params.userId }
    );
  }
}

async function hasActivePremiumEntitlementForSubscription(
  userId: string,
  subscriptionId: string
): Promise<boolean> {
  const snap = await db()
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection(COLLECTIONS.entitlements)
    .where("key", "==", ENTITLEMENT_KEYS.premium)
    .where("isActive", "==", true)
    .where("subscriptionId", "==", subscriptionId)
    .limit(1)
    .get();
  return !snap.empty;
}

async function upsertPremiumEntitlement(params: {
  userId: string;
  subscriptionId: string;
  expiresAt: Date;
  sellerId?: string;
  affiliateId?: string;
  couponId?: string;
}): Promise<void> {
  const entCol = db()
    .collection(COLLECTIONS.users)
    .doc(params.userId)
    .collection(COLLECTIONS.entitlements);

  const bySubscription = await entCol
    .where("key", "==", ENTITLEMENT_KEYS.premium)
    .where("subscriptionId", "==", params.subscriptionId)
    .limit(1)
    .get();

  const now = admin.firestore.Timestamp.now();
  const expiresTs = admin.firestore.Timestamp.fromDate(params.expiresAt);

  if (!bySubscription.empty) {
    await bySubscription.docs[0].ref.update({
      expiresAt: expiresTs,
      isActive: true,
      updatedAt: now,
    });
    return;
  }

  const legacyActive = await entCol
    .where("key", "==", ENTITLEMENT_KEYS.premium)
    .where("isActive", "==", true)
    .limit(1)
    .get();

  if (!legacyActive.empty) {
    await legacyActive.docs[0].ref.update({
      expiresAt: expiresTs,
      subscriptionId: params.subscriptionId,
      isActive: true,
      grantSource: GRANT_SOURCE.mercadoPago,
      updatedAt: now,
    });
    return;
  }

  await entCol.add({
    key: ENTITLEMENT_KEYS.premium,
    grantedAt: now,
    expiresAt: expiresTs,
    grantSource: GRANT_SOURCE.mercadoPago,
    sellerId: params.sellerId ?? null,
    affiliateId: params.affiliateId ?? null,
    couponId: params.couponId ?? null,
    subscriptionId: params.subscriptionId,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });
}

/**
 * Pagamento recusado/cancelado no MP — P0-3: não revoga Premium se nunca houve succeeded.
 */
export async function markPaymentRejected(
  paymentId: string,
  providerPaymentId: string
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return;

  const paymentData = paymentSnap.data()!;
  const previousStatus = paymentData.status as string;

  if (!shouldRevokePremiumEntitlementOnPaymentReject(previousStatus)) {
    await paymentRef.update({
      status: PAYMENT_STATUS.canceled,
      providerPaymentId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logSubscription("payment.rejected_without_revoke", {
      paymentId,
      previousStatus,
      userId: paymentData.userId,
    });
    return;
  }

  await updatePaymentAndSubscriptionStatus(
    paymentId,
    providerPaymentId,
    PAYMENT_STATUS.canceled,
    SUBSCRIPTION_STATUS.canceled
  );
}

/** @deprecated Use markPaymentRejected — mantido para compatibilidade interna. */
export async function cancelSubscriptionFromPayment(
  paymentId: string,
  providerPaymentId: string
): Promise<void> {
  return markPaymentRejected(paymentId, providerPaymentId);
}

export async function refundSubscriptionFromPayment(
  paymentId: string,
  providerPaymentId: string
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return;

  const paymentData = paymentSnap.data()!;
  if (paymentData.status !== PAYMENT_STATUS.succeeded) {
    await paymentRef.update({
      status: PAYMENT_STATUS.refunded,
      providerPaymentId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logSubscription("payment.refund_without_prior_success", { paymentId });
    return;
  }

  await updatePaymentAndSubscriptionStatus(
    paymentId,
    providerPaymentId,
    PAYMENT_STATUS.refunded,
    SUBSCRIPTION_STATUS.canceled
  );
}

export async function markPaymentProcessing(
  paymentId: string,
  providerPaymentId: string
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return;
  if (paymentSnap.data()?.status === PAYMENT_STATUS.succeeded) {
    return;
  }
  await paymentRef.update({
    status: PAYMENT_STATUS.processing,
    providerPaymentId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function updatePaymentAndSubscriptionStatus(
  paymentId: string,
  providerPaymentId: string,
  paymentStatus: string,
  subscriptionStatus: string
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return;

  const paymentData = paymentSnap.data()!;
  if (
    paymentData.status === PAYMENT_STATUS.refunded &&
    paymentStatus === PAYMENT_STATUS.canceled
  ) {
    return;
  }

  const now = admin.firestore.Timestamp.now();
  const subscriptionId = paymentData.subscriptionId as string | undefined;
  const userId = paymentData.userId as string;

  await paymentRef.update({
    status: paymentStatus,
    providerPaymentId,
    updatedAt: now,
  });

  if (subscriptionId) {
    await db().collection(COLLECTIONS.subscriptions).doc(subscriptionId).update({
      status: subscriptionStatus,
      canceledAt: now,
      updatedAt: now,
    });
    await deactivatePremiumEntitlementsForSubscription(userId, subscriptionId);
  } else {
    logSubscription("payment.revoke_skipped_no_subscription", {
      paymentId,
      paymentStatus,
    });
  }
}

export async function deactivatePremiumEntitlementsForSubscription(
  userId: string,
  subscriptionId?: string
): Promise<void> {
  if (!subscriptionId) {
    logSubscription("deactivate.skipped_no_subscription_id", { userId });
    return;
  }

  const entCol = db()
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection(COLLECTIONS.entitlements);

  const snap = await entCol
    .where("key", "==", ENTITLEMENT_KEYS.premium)
    .where("subscriptionId", "==", subscriptionId)
    .where("isActive", "==", true)
    .get();

  if (snap.empty) {
    return;
  }

  const batch = db().batch();
  const now = admin.firestore.Timestamp.now();

  for (const doc of snap.docs) {
    batch.update(doc.ref, { isActive: false, updatedAt: now });
  }

  await batch.commit();
  logSubscription("deactivate.premium_for_subscription", {
    userId,
    subscriptionId,
    count: snap.size,
  });
}

export async function expireDueSubscriptions(): Promise<number> {
  const now = admin.firestore.Timestamp.now();
  let total = 0;
  let rounds = 0;
  const maxRounds = 20;

  while (rounds < maxRounds) {
    const snap = await db()
      .collection(COLLECTIONS.subscriptions)
      .where("status", "==", SUBSCRIPTION_STATUS.active)
      .where("currentPeriodEnd", "<", now)
      .limit(100)
      .get();

    if (snap.empty) break;

    for (const doc of snap.docs) {
      const data = doc.data();
      await doc.ref.update({
        status: SUBSCRIPTION_STATUS.expired,
        updatedAt: now,
      });
      await deactivatePremiumEntitlementsForSubscription(
        data.userId as string,
        doc.id
      );
      total++;
    }
    rounds++;
  }

  if (rounds === maxRounds) {
    logSubscription("expire.max_rounds_reached", { total });
  }

  return total;
}

export async function resolveCouponId(code?: string): Promise<string | undefined> {
  if (!code?.trim()) return undefined;
  const snap = await db()
    .collection(COLLECTIONS.coupons)
    .where("code", "==", code.trim().toUpperCase())
    .where("isActive", "==", true)
    .limit(1)
    .get();
  if (snap.empty) return undefined;
  return snap.docs[0].id;
}

export async function incrementCouponUse(couponId: string): Promise<void> {
  await db()
    .collection(COLLECTIONS.coupons)
    .doc(couponId)
    .update({ usedCount: admin.firestore.FieldValue.increment(1) });
}

export async function trackSellerConversion(sellerId: string): Promise<void> {
  await db()
    .collection(COLLECTIONS.sellers)
    .doc(sellerId)
    .update({ totalSales: admin.firestore.FieldValue.increment(1) });
}

export async function trackAffiliateConversion(affiliateId: string): Promise<void> {
  await db()
    .collection(COLLECTIONS.affiliates)
    .doc(affiliateId)
    .update({ conversions: admin.firestore.FieldValue.increment(1) });
}

/** Pagamentos do usuário elegíveis a reconciliação (pending/processing/succeeded incompleto). */
export async function listPaymentsToReconcileForUser(
  userId: string,
  limit = 5
): Promise<string[]> {
  const snap = await db()
    .collection(COLLECTIONS.payments)
    .where("userId", "==", userId)
    .limit(30)
    .get();

  const docs = [...snap.docs].sort((a, b) => {
    const aTs = (a.data().updatedAt as admin.firestore.Timestamp)?.toMillis?.() ?? 0;
    const bTs = (b.data().updatedAt as admin.firestore.Timestamp)?.toMillis?.() ?? 0;
    return bTs - aTs;
  });

  const ids: string[] = [];
  for (const doc of docs) {
    if (ids.length >= limit) break;
    const data = doc.data();
    const status = data.status as string;

    if (
      status === PAYMENT_STATUS.pending ||
      status === PAYMENT_STATUS.processing
    ) {
      ids.push(doc.id);
      continue;
    }

    if (status === PAYMENT_STATUS.succeeded) {
      const subId = data.subscriptionId as string | undefined;
      if (!subId) {
        ids.push(doc.id);
        continue;
      }
      const entOk = await hasActivePremiumEntitlementForSubscription(
        userId,
        subId
      );
      if (!entOk) ids.push(doc.id);
    }
  }
  return ids;
}
