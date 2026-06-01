import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function readSrc(path) {
  return readFileSync(join(root, "src", path), "utf8");
}

const CALLABLE_LIMITS = [
  { file: "createCheckout.ts", export: "createMercadoPagoCheckout", action: "checkout.mercado_pago" },
  {
    file: "subscription/paymentReconciliation.ts",
    export: "reconcileMyMercadoPagoPayments",
    action: "payment.reconcile_my",
  },
  { file: "push/callables.ts", export: "createPushCampaign", action: "push.campaign_create" },
  {
    file: "push/callables.ts",
    export: "notifyLiveEventBroadcast",
    action: "push.live_broadcast",
  },
  { file: "push/callables.ts", export: "registerFcmToken", action: "fcm.register_token" },
  { file: "accountDeletion.ts", export: "deleteMyAccount", action: "account.delete" },
];

for (const item of CALLABLE_LIMITS) {
  test(`rate limit em ${item.export}`, () => {
    const src = readSrc(item.file);
    assert.match(
      src,
      new RegExp(
        `export const ${item.export}[\\s\\S]*?assertRateLimitForCallable\\([\\s\\S]*?RATE_LIMIT_ACTIONS\\.[\\w]+`
      )
    );
  });
}

test("C/D) limites documentados no config", () => {
  const cfg = readSrc("rateLimit/rateLimitConfig.ts");
  assert.match(cfg, /checkout\.mercado_pago/);
  assert.match(cfg, /maxRequests: 3/);
  assert.match(cfg, /maxRequests: 10/);
  assert.match(cfg, /maxRequests: 20/);
  assert.match(cfg, /account\.delete[\s\S]*maxRequests: 2/);
  assert.match(cfg, /authLogin[\s\S]*maxRequests: 20/);
  assert.match(cfg, /authSignUp[\s\S]*maxRequests: 10/);
});

test("auth blocking exportado", () => {
  const index = readSrc("index.ts");
  assert.match(index, /rateLimitBeforeSignIn/);
  assert.match(index, /rateLimitBeforeCreate/);
  assert.match(index, /rateLimitPasswordReset/);
});

test("auditoria rate_limit.blocked", () => {
  const audit = readSrc("rateLimit/rateLimitAudit.ts");
  assert.match(audit, /rate_limit\.blocked/);
  assert.match(audit, /blocked/);
  assert.match(audit, /reason/);
});

test("coleção platform_rate_limits", () => {
  const constants = readSrc("constants.ts");
  assert.match(constants, /platform_rate_limits/);
});
