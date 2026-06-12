import { onCall, HttpsError } from "firebase-functions/v2/https";
import { MercadoPagoConfig, Preference } from "mercadopago";
import * as admin from "firebase-admin";
import {
  assertMercadoPagoCheckoutConfig,
  getCheckoutUrls,
  mercadoPagoAccessToken,
} from "./config";
import {
  COLLECTIONS,
  PAYMENT_PROVIDER,
  PAYMENT_STATUS,
} from "./constants";
import {
  buildAppliedCouponPricing,
  resolveValidatedCoupon,
} from "./subscription/couponPricing";
import { logSubscription } from "./subscription/subscriptionLogger";
import { appCheckCallableOptions } from "./callableOptions";
import { assertRateLimitForCallable } from "./rateLimit/assertRateLimit";
import { RATE_LIMIT_ACTIONS } from "./rateLimit/rateLimitConfig";

interface CheckoutRequest {
  planId: string;
  billingPeriod: "monthly" | "yearly";
  couponCode?: string;
  sellerId?: string;
  affiliateId?: string;
}

export const createMercadoPagoCheckout = onCall(
  appCheckCallableOptions({ secrets: [mercadoPagoAccessToken] }),
  async (request) => {
    if (!request.auth?.uid) {
      console.warn(
        "[createMercadoPagoCheckout] request.auth ausente — " +
          "verifique token Firebase Auth no cliente (região southamerica-east1).",
      );
      throw new HttpsError("unauthenticated", "Login necessário.");
    }

    await assertRateLimitForCallable(request, RATE_LIMIT_ACTIONS.checkout);

    const notificationUrl = assertMercadoPagoCheckoutConfig();

    const data = request.data as CheckoutRequest;
    const planId = data?.planId?.trim();
    const billingPeriod = data?.billingPeriod;

    if (!planId || !billingPeriod) {
      throw new HttpsError("invalid-argument", "planId e billingPeriod são obrigatórios.");
    }
    if (billingPeriod !== "monthly" && billingPeriod !== "yearly") {
      throw new HttpsError("invalid-argument", "billingPeriod deve ser monthly ou yearly.");
    }

    const db = admin.firestore();
    const planSnap = await db.collection(COLLECTIONS.subscriptionPlans).doc(planId).get();
    if (!planSnap.exists || planSnap.data()?.isActive !== true) {
      throw new HttpsError("not-found", "Plano não encontrado ou inativo.");
    }

    const plan = planSnap.data()!;
    const baseAmount =
      billingPeriod === "yearly"
        ? (plan.priceYearly as number) ?? 0
        : (plan.priceMonthly as number) ?? 0;

    if (baseAmount <= 0) {
      throw new HttpsError("failed-precondition", "Plano sem preço configurado.");
    }

    const userId = request.auth.uid;
    const userEmail = request.auth.token.email ?? undefined;

    const coupon = await resolveValidatedCoupon(data.couponCode, planId);
    const pricing = coupon
      ? buildAppliedCouponPricing(baseAmount, coupon)
      : null;
    const amount = pricing?.finalAmount ?? baseAmount;
    const couponId = pricing?.couponId ?? null;

    const paymentRef = db.collection(COLLECTIONS.payments).doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await paymentRef.set({
      userId,
      planId,
      amount,
      currency: plan.currency ?? "BRL",
      status: PAYMENT_STATUS.pending,
      provider: PAYMENT_PROVIDER.mercadoPago,
      couponId: couponId ?? null,
      sellerId: data.sellerId ?? null,
      affiliateId: data.affiliateId ?? null,
      metadata: {
        billingPeriod,
        planName: plan.name,
        couponCode: data.couponCode?.trim().toUpperCase() ?? null,
        ...(pricing
          ? {
              originalAmount: pricing.originalAmount,
              discountType: pricing.discountType,
              discountValue: pricing.discountValue,
            }
          : {}),
      },
      createdAt: now,
      updatedAt: now,
    });

    const accessToken = mercadoPagoAccessToken.value();
    const client = new MercadoPagoConfig({ accessToken });
    const preferenceClient = new Preference(client);
    const urls = getCheckoutUrls();

    const periodLabel = billingPeriod === "yearly" ? "Anual" : "Mensal";
    const discountLabel = pricing
      ? pricing.discountType === "percent"
        ? ` (-${pricing.discountValue}%)`
        : ` (-R$ ${pricing.discountValue.toFixed(2).replace(".", ",")})`
      : "";

    logSubscription("checkout.creating_preference", {
      paymentId: paymentRef.id,
      userId,
      planId,
      hasNotificationUrl: Boolean(notificationUrl),
      originalAmount: pricing?.originalAmount ?? baseAmount,
      finalAmount: amount,
      couponId: couponId ?? null,
    });

    const preference = await preferenceClient.create({
      body: {
        items: [
          {
            id: planId,
            title: `${plan.name} — ${periodLabel}${discountLabel}`,
            description: (plan.description as string) ?? "",
            quantity: 1,
            unit_price: amount,
            currency_id: "BRL",
          },
        ],
        payer: userEmail ? { email: userEmail } : undefined,
        back_urls: {
          success: urls.success,
          failure: urls.failure,
          pending: urls.pending,
        },
        auto_return: "approved",
        external_reference: paymentRef.id,
        notification_url: notificationUrl || undefined,
        metadata: {
          userId,
          planId,
          billingPeriod,
          paymentId: paymentRef.id,
          sellerId: data.sellerId ?? null,
          affiliateId: data.affiliateId ?? null,
          couponId: couponId ?? null,
        },
      },
    });

    const preferenceId = preference.id ?? "";
    const checkoutUrl =
      preference.init_point ??
      (process.env.MERCADOPAGO_SANDBOX === "true"
        ? preference.sandbox_init_point
        : null) ??
      "";

    if (!checkoutUrl) {
      throw new HttpsError("internal", "Mercado Pago não retornou URL de checkout.");
    }

    await paymentRef.update({
      providerPaymentId: preferenceId,
      metadata: {
        billingPeriod,
        planName: plan.name,
        couponCode: data.couponCode?.trim().toUpperCase() ?? null,
        preferenceId,
        checkoutUrl,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      paymentId: paymentRef.id,
      preferenceId,
      checkoutUrl,
      amount,
      currency: "BRL",
      billingPeriod,
      ...(pricing
        ? {
            originalAmount: pricing.originalAmount,
            discountApplied: pricing.originalAmount - pricing.finalAmount,
            couponCode: pricing.couponCode,
          }
        : {}),
    };
  }
);
