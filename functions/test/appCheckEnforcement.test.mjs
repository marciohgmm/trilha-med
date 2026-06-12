import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function readSrc(relativePath) {
  return readFileSync(join(root, "src", relativePath), "utf8");
}

function assertUsesAppCheckHelper(relativePath, exportName) {
  const src = readSrc(relativePath);
  assert.match(
    src,
    new RegExp(
      `export const ${exportName}\\s*=\\s*onCall\\([\\s\\S]*?appCheckCallableOptions\\(`,
    ),
    `${exportName} deve usar appCheckCallableOptions()`,
  );
}

const PROTECTED_CALLABLES = [
  { file: "createCheckout.ts", name: "createMercadoPagoCheckout" },
  {
    file: "subscription/paymentReconciliation.ts",
    name: "reconcileMyMercadoPagoPayments",
  },
  { file: "accountDeletion.ts", name: "deleteMyAccount" },
  { file: "push/callables.ts", name: "registerFcmToken" },
  { file: "push/callables.ts", name: "createPushCampaign" },
  { file: "push/callables.ts", name: "notifyLiveEventBroadcast" },
  { file: "push/callables.ts", name: "notifyLiveEventUser" },
  { file: "push/callables.ts", name: "scheduleLiveEventReminders" },
];

for (const { file, name } of PROTECTED_CALLABLES) {
  test(`App Check: ${name} exige token`, () => {
    assertUsesAppCheckHelper(file, name);
  });
}

test("App Check: mercadopagoWebhook permanece onRequest sem enforceAppCheck", () => {
  const src = readSrc("webhook.ts");
  assert.match(src, /export const mercadopagoWebhook\s*=\s*onRequest/);
  assert.doesNotMatch(src, /enforceAppCheck:\s*true/);
});

test("App Check: helper central appCheckCallableOptions", () => {
  const src = readSrc("callableOptions.ts");
  assert.match(src, /enforceAppCheck:\s*true/);
  assert.match(src, /invoker:\s*"public"/);
});
