import assert from "node:assert";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  shouldRevokePremiumEntitlementOnPaymentReject,
} from "../lib/subscription/subscriptionRevokePolicy.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

test("P0-3: não revoga premium se pagamento nunca foi succeeded", () => {
  assert.strictEqual(
    shouldRevokePremiumEntitlementOnPaymentReject("pending"),
    false
  );
  assert.strictEqual(
    shouldRevokePremiumEntitlementOnPaymentReject("processing"),
    false
  );
  assert.strictEqual(
    shouldRevokePremiumEntitlementOnPaymentReject("canceled"),
    false
  );
  assert.strictEqual(
    shouldRevokePremiumEntitlementOnPaymentReject("succeeded"),
    true
  );
});

test("subscriptionService: deactivate exige subscriptionId", () => {
  const src = readFileSync(join(root, "src/subscriptionService.ts"), "utf8");
  assert.match(
    src,
    /if \(!subscriptionId\)/
  );
  assert.match(src, /deactivate\.skipped_no_subscription_id/);
});

test("paymentProcessor: approved sempre chama activatePremiumFromPayment", () => {
  const src = readFileSync(join(root, "src/subscription/paymentProcessor.ts"), "utf8");
  assert.match(src, /activatePremiumFromPayment/);
  assert.doesNotMatch(
    src,
    /localPayment\.status !== PAYMENT_STATUS\.succeeded[\s\S]*?return/
  );
});

test("createCheckout: exige config via assertMercadoPagoCheckoutConfig", () => {
  const src = readFileSync(join(root, "src/createCheckout.ts"), "utf8");
  assert.match(src, /assertMercadoPagoCheckoutConfig/);
});

test("config: MERCADOPAGO_WEBHOOK_URL validado", () => {
  const src = readFileSync(join(root, "src/config.ts"), "utf8");
  assert.match(src, /MERCADOPAGO_WEBHOOK_URL/);
  assert.match(src, /failed-precondition/);
});
