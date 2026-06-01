import * as admin from "firebase-admin";
import { COLLECTIONS, PAYMENT_STATUS } from "../constants";
import {
  activatePremiumFromPayment,
  incrementCouponUse,
  markPaymentProcessing,
  markPaymentRejected,
  refundSubscriptionFromPayment,
  trackAffiliateConversion,
  trackSellerConversion,
} from "../subscriptionService";
import { ANALYTICS_EVENTS, mirrorAnalyticsEvent } from "../analyticsService";
import {
  fetchMercadoPagoPayment,
  isMercadoPagoPaymentId,
  MpPaymentRecord,
  searchMercadoPagoPaymentsByExternalReference,
} from "./mercadoPagoPaymentClient";
import { logSubscription, logSubscriptionError } from "./subscriptionLogger";

const db = () => admin.firestore();

export type ProcessPaymentSource = "webhook" | "reconcile_scheduled" | "reconcile_callable";

/**
 * Processa um pagamento MP já validado (ou recém-buscado na API).
 * Idempotente — seguro para retries de webhook e jobs de reconciliação.
 */
export async function processMercadoPagoPaymentRecord(
  mpPayment: MpPaymentRecord,
  source: ProcessPaymentSource
): Promise<"ok" | "ignored" | "not_found"> {
  const externalReference = mpPayment.external_reference as string | undefined;
  if (!externalReference?.trim()) {
    logSubscription("payment.skip_no_external_reference", {
      source,
      mpPaymentId: mpPayment.id,
    });
    return "ignored";
  }

  const paymentRef = db().collection(COLLECTIONS.payments).doc(externalReference);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    logSubscription("payment.local_not_found", {
      source,
      paymentId: externalReference,
      mpPaymentId: mpPayment.id,
    });
    return "not_found";
  }

  const localPayment = paymentSnap.data()!;
  const mpStatus = String(mpPayment.status ?? "");
  const metadata = (mpPayment.metadata ?? {}) as Record<string, string>;
  const billingPeriod =
    (localPayment.metadata?.billingPeriod as "monthly" | "yearly") ??
    (metadata.billingPeriod as "monthly" | "yearly") ??
    "monthly";

  const userId = localPayment.userId as string;
  const planId = (localPayment.planId as string) ?? metadata.planId;
  const sellerId = (localPayment.sellerId as string | null) ?? metadata.sellerId;
  const affiliateId =
    (localPayment.affiliateId as string | null) ?? metadata.affiliateId;
  const couponId = (localPayment.couponId as string | null) ?? metadata.couponId;
  const amount =
    (mpPayment.transaction_amount as number) ?? (localPayment.amount as number);

  logSubscription("payment.process", {
    source,
    paymentId: externalReference,
    mpPaymentId: mpPayment.id,
    mpStatus,
    localStatus: localPayment.status,
    userId,
  });

  if (mpStatus === "approved") {
    const result = await activatePremiumFromPayment({
      userId,
      planId,
      billingPeriod,
      paymentId: externalReference,
      providerPaymentId: String(mpPayment.id),
      amount,
      sellerId: sellerId ?? undefined,
      affiliateId: affiliateId ?? undefined,
      couponId: couponId ?? undefined,
    });

    const wasAlreadySucceeded =
      localPayment.status === PAYMENT_STATUS.succeeded;

    if (!wasAlreadySucceeded) {
      if (couponId) await incrementCouponUse(couponId);
      if (sellerId) await trackSellerConversion(sellerId);
      if (affiliateId) await trackAffiliateConversion(affiliateId);

      await mirrorAnalyticsEvent(ANALYTICS_EVENTS.purchaseApproved, userId, {
        plan_id: planId,
        payment_id: externalReference,
        amount,
        billing_period: billingPeriod,
        source,
      });
    }

    logSubscription("payment.activated", {
      source,
      paymentId: externalReference,
      subscriptionId: result.subscriptionId,
      recovered: wasAlreadySucceeded,
    });
    return "ok";
  }

  if (
    mpStatus === "cancelled" ||
    mpStatus === "rejected" ||
    mpStatus === "expired"
  ) {
    await markPaymentRejected(externalReference, String(mpPayment.id));
    if (localPayment.status !== PAYMENT_STATUS.canceled) {
      await mirrorAnalyticsEvent(ANALYTICS_EVENTS.purchaseCancelled, userId, {
        plan_id: planId,
        payment_id: externalReference,
        source,
      });
    }
    return "ok";
  }

  if (mpStatus === "refunded" || mpStatus === "charged_back") {
    await refundSubscriptionFromPayment(externalReference, String(mpPayment.id));
    return "ok";
  }

  if (mpStatus === "pending" || mpStatus === "in_process") {
    await markPaymentProcessing(externalReference, String(mpPayment.id));
    return "ok";
  }

  logSubscription("payment.unhandled_status", {
    source,
    mpStatus,
    paymentId: externalReference,
  });
  return "ignored";
}

/** Busca na API MP e processa (reconciliação / webhook). */
export async function processMercadoPagoPaymentById(
  accessToken: string,
  mpPaymentId: string,
  source: ProcessPaymentSource
): Promise<"ok" | "ignored" | "not_found" | "mp_not_found"> {
  const mpPayment = await fetchMercadoPagoPayment(accessToken, mpPaymentId);
  if (!mpPayment) {
    logSubscription("payment.mp_not_found", { source, mpPaymentId });
    return "mp_not_found";
  }
  return processMercadoPagoPaymentRecord(mpPayment, source);
}

/** Reconcilia documento local `platform_payments` via API MP (id ou external_reference). */
export async function reconcileLocalPaymentDoc(
  accessToken: string,
  paymentId: string,
  source: ProcessPaymentSource
): Promise<void> {
  const paymentRef = db().collection(COLLECTIONS.payments).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) return;

  const data = paymentSnap.data()!;
  const providerPaymentId = (data.providerPaymentId as string | undefined)?.trim();

  try {
    if (providerPaymentId && isMercadoPagoPaymentId(providerPaymentId)) {
      const outcome = await processMercadoPagoPaymentById(
        accessToken,
        providerPaymentId,
        source
      );
      if (outcome === "ok" || outcome === "ignored") return;
    }

    const searchResults = await searchMercadoPagoPaymentsByExternalReference(
      accessToken,
      paymentId
    );
    if (searchResults.length === 0) {
      logSubscription("reconcile.no_mp_payments", { paymentId, source });
      return;
    }

    const approved = searchResults.find((p) => p.status === "approved");
    const toProcess = approved ? [approved] : [searchResults[0]];

    for (const mpPayment of toProcess) {
      await processMercadoPagoPaymentRecord(mpPayment, source);
    }
  } catch (err) {
    logSubscriptionError("reconcile.payment_failed", err, { paymentId, source });
  }
}
