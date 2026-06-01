import { PAYMENT_STATUS } from "../constants";

/** P0-3: só revoga entitlement premium se o pagamento chegou a succeeded. */
export function shouldRevokePremiumEntitlementOnPaymentReject(
  previousPaymentStatus: string
): boolean {
  return previousPaymentStatus === PAYMENT_STATUS.succeeded;
}
