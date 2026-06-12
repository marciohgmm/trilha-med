import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { COLLECTIONS } from "../constants";

export type CouponDiscountType = "percent" | "fixed";

export interface CouponRecord {
  id: string;
  code: string;
  discountType: CouponDiscountType;
  discountValue: number;
  maxUses: number;
  usedCount: number;
  validFrom?: admin.firestore.Timestamp;
  validUntil?: admin.firestore.Timestamp;
  applicablePlanIds: string[];
  isActive: boolean;
}

export interface AppliedCouponPricing {
  couponId: string;
  couponCode: string;
  originalAmount: number;
  finalAmount: number;
  discountType: CouponDiscountType;
  discountValue: number;
}

const db = () => admin.firestore();

function parseCouponRecord(
  id: string,
  data: admin.firestore.DocumentData
): CouponRecord {
  const rawType = String(data.discountType ?? "percent");
  const discountType: CouponDiscountType =
    rawType === "fixed" ? "fixed" : "percent";
  return {
    id,
    code: String(data.code ?? "").trim().toUpperCase(),
    discountType,
    discountValue: Number(data.discountValue ?? 0),
    maxUses: Number(data.maxUses ?? 0),
    usedCount: Number(data.usedCount ?? 0),
    validFrom: data.validFrom as admin.firestore.Timestamp | undefined,
    validUntil: data.validUntil as admin.firestore.Timestamp | undefined,
    applicablePlanIds: Array.isArray(data.applicablePlanIds)
      ? data.applicablePlanIds.map((e) => String(e))
      : [],
    isActive: data.isActive === true,
  };
}

/** Valida cupom ativo, vigência, usos e planos elegíveis. */
export function assertCouponValidForCheckout(
  coupon: CouponRecord,
  planId: string,
  now: Date = new Date()
): void {
  if (!coupon.isActive) {
    throw new HttpsError("failed-precondition", "Cupom inativo.");
  }

  if (coupon.discountValue <= 0) {
    throw new HttpsError("failed-precondition", "Cupom sem desconto configurado.");
  }

  if (coupon.discountType === "percent" && coupon.discountValue > 100) {
    throw new HttpsError("failed-precondition", "Cupom percentual inválido.");
  }

  if (coupon.maxUses > 0 && coupon.usedCount >= coupon.maxUses) {
    throw new HttpsError("failed-precondition", "Cupom esgotado.");
  }

  const from = coupon.validFrom?.toDate?.();
  if (from && now < from) {
    throw new HttpsError("failed-precondition", "Cupom ainda não está válido.");
  }

  const until = coupon.validUntil?.toDate?.();
  if (until && now > until) {
    throw new HttpsError("failed-precondition", "Cupom expirado.");
  }

  if (
    coupon.applicablePlanIds.length > 0 &&
    !coupon.applicablePlanIds.includes(planId)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Cupom não válido para este plano."
    );
  }
}

/** Calcula valor final com desconto percentual ou fixo (BRL, 2 casas). */
export function applyCouponDiscount(
  baseAmount: number,
  discountType: CouponDiscountType,
  discountValue: number
): number {
  if (baseAmount <= 0) {
    throw new HttpsError("failed-precondition", "Plano sem preço configurado.");
  }

  let finalAmount: number;
  if (discountType === "fixed") {
    finalAmount = baseAmount - discountValue;
  } else {
    finalAmount = baseAmount * (1 - discountValue / 100);
  }

  finalAmount = Math.round(finalAmount * 100) / 100;

  if (finalAmount < 0.5) {
    throw new HttpsError(
      "failed-precondition",
      "Desconto deixa o valor abaixo do mínimo do Mercado Pago."
    );
  }

  if (finalAmount >= baseAmount) {
    throw new HttpsError(
      "failed-precondition",
      "Cupom não reduz o valor do plano."
    );
  }

  return finalAmount;
}

/**
 * Busca cupom por código. Se [code] vazio, retorna null.
 * Se informado e inválido/inexistente, lança HttpsError.
 */
export async function resolveValidatedCoupon(
  code: string | undefined,
  planId: string
): Promise<CouponRecord | null> {
  const trimmed = code?.trim();
  if (!trimmed) return null;

  const snap = await db()
    .collection(COLLECTIONS.coupons)
    .where("code", "==", trimmed.toUpperCase())
    .limit(1)
    .get();

  if (snap.empty) {
    throw new HttpsError("not-found", "Cupom não encontrado.");
  }

  const doc = snap.docs[0];
  const coupon = parseCouponRecord(doc.id, doc.data());
  assertCouponValidForCheckout(coupon, planId);
  return coupon;
}

/** Preço final para checkout Mercado Pago. */
export function buildAppliedCouponPricing(
  baseAmount: number,
  coupon: CouponRecord
): AppliedCouponPricing {
  const finalAmount = applyCouponDiscount(
    baseAmount,
    coupon.discountType,
    coupon.discountValue
  );
  return {
    couponId: coupon.id,
    couponCode: coupon.code,
    originalAmount: baseAmount,
    finalAmount,
    discountType: coupon.discountType,
    discountValue: coupon.discountValue,
  };
}
