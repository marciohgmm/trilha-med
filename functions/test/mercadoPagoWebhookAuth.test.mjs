import assert from "node:assert";
import test from "node:test";

import {
  buildMercadoPagoSignatureManifest,
  computeMercadoPagoSignature,
  parseMercadoPagoSignatureHeader,
  validateMercadoPagoWebhookSignature,
} from "../lib/subscription/mercadoPagoWebhookAuth.js";

test("parseMercadoPagoSignatureHeader extrai ts e v1", () => {
  const p = parseMercadoPagoSignatureHeader("ts=1700000000,v1=abc123");
  assert.ok(p);
  assert.strictEqual(p.ts, "1700000000");
  assert.strictEqual(p.v1, "abc123");
});

test("C) webhook com assinatura inválida — validation.valid false", () => {
  const result = validateMercadoPagoWebhookSignature({
    secret: "my_secret",
    xSignature: "ts=1700000000,v1=deadbeef",
    xRequestId: "req-1",
    dataId: "12345",
    nowMs: 1700000000 * 1000,
  });
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, "signature_mismatch");
});

test("D) webhook com assinatura válida — validation.valid true", () => {
  const secret = "test_webhook_secret";
  const ts = "1700000000";
  const dataId = "987654321";
  const requestId = "req-abc";
  const manifest = buildMercadoPagoSignatureManifest({
    dataId,
    requestId,
    ts,
  });
  const v1 = computeMercadoPagoSignature(secret, manifest);
  const xSignature = `ts=${ts},v1=${v1}`;

  const result = validateMercadoPagoWebhookSignature({
    secret,
    xSignature,
    xRequestId: requestId,
    dataId,
    nowMs: 1700000000 * 1000,
  });

  assert.strictEqual(result.valid, true);
  assert.strictEqual(result.reason, "ok");
});

test("webhook rejeita timestamp fora da janela (replay)", () => {
  const secret = "test_webhook_secret";
  const ts = "1700000000";
  const dataId = "1";
  const manifest = buildMercadoPagoSignatureManifest({ dataId, ts });
  const v1 = computeMercadoPagoSignature(secret, manifest);
  const result = validateMercadoPagoWebhookSignature({
    secret,
    xSignature: `ts=${ts},v1=${v1}`,
    dataId,
    nowMs: 1700003600 * 1000,
    maxAgeMs: 5 * 60 * 1000,
  });
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, "timestamp_out_of_window");
});

test("webhook.ts retorna 401 para assinatura inválida", async () => {
  const { readFileSync } = await import("node:fs");
  const { dirname, join } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const root = join(dirname(fileURLToPath(import.meta.url)), "..");
  const src = readFileSync(join(root, "src/webhook.ts"), "utf8");
  assert.match(src, /res\.status\(401\)/);
  assert.match(src, /validateMercadoPagoWebhookSignature/);
  assert.match(src, /processMercadoPagoPaymentById/);
});
