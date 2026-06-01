import assert from "node:assert";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  buildMercadoPagoSignatureManifest,
  computeMercadoPagoSignature,
  validateMercadoPagoWebhookSignature,
} from "../lib/subscription/mercadoPagoWebhookAuth.js";

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), "../..");
const functionsRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

test("firestore.rules — legal_acceptances append-only", () => {
  const rules = readFileSync(join(projectRoot, "firestore.rules"), "utf8");
  assert.match(rules, /match \/legal_acceptances\/\{acceptanceId\}/);
  assert.match(rules, /allow update, delete: if false/);
  assert.match(rules, /policyVersion is string/);
});

test("deleteMyAccount exige confirmação EXCLUIR", () => {
  const src = readFileSync(join(functionsRoot, "src/accountDeletion.ts"), "utf8");
  assert.match(src, /CONFIRMATION_PHRASE = "EXCLUIR"/);
  assert.match(src, /account\.deletion_requested/);
  assert.match(src, /deleteUserSubcollections/);
  assert.match(src, /admin\.auth\(\)\.deleteUser/);
});

test("deleteMyAccount preserva pagamentos (não deleta platform_payments)", () => {
  const src = readFileSync(join(functionsRoot, "src/accountDeletion.ts"), "utf8");
  assert.doesNotMatch(src, /platform_payments.*\.delete/);
});

test("index exporta deleteMyAccount", () => {
  const src = readFileSync(join(functionsRoot, "src/index.ts"), "utf8");
  assert.match(src, /deleteMyAccount/);
});
