import assert from "node:assert";
import test from "node:test";

import {
  applyCouponDiscount,
  assertCouponValidForCheckout,
} from "../lib/subscription/couponPricing.js";

test("applyCouponDiscount: percentual 10% sobre 100 = 90", () => {
  assert.strictEqual(applyCouponDiscount(100, "percent", 10), 90);
});

test("applyCouponDiscount: fixo R$ 15 sobre 49.90 = 34.90", () => {
  assert.strictEqual(applyCouponDiscount(49.9, "fixed", 15), 34.9);
});

test("applyCouponDiscount: rejeita valor final abaixo do mínimo MP", () => {
  assert.throws(
    () => applyCouponDiscount(10, "fixed", 9.8),
    /mínimo do Mercado Pago/
  );
});

test("assertCouponValidForCheckout: cupom esgotado", () => {
  assert.throws(
    () =>
      assertCouponValidForCheckout(
        {
          id: "c1",
          code: "PROMO",
          discountType: "percent",
          discountValue: 10,
          maxUses: 5,
          usedCount: 5,
          applicablePlanIds: [],
          isActive: true,
        },
        "premium"
      ),
    /esgotado/
  );
});

test("createCheckout usa cupom no unit_price", async () => {
  const { readFileSync } = await import("node:fs");
  const { dirname, join } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const root = join(dirname(fileURLToPath(import.meta.url)), "..");
  const src = readFileSync(join(root, "src/createCheckout.ts"), "utf8");
  assert.match(src, /resolveValidatedCoupon/);
  assert.match(src, /unit_price: amount/);
  assert.match(src, /buildAppliedCouponPricing/);
});
