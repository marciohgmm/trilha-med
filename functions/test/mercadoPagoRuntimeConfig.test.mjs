import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
  shouldSkipMercadoPagoWebhookSignature,
  webhookUrlLooksValid,
  normalizeWebhookUrl,
} from "../lib/mercadoPagoRuntimeConfig.js";

describe("mercadoPagoRuntimeConfig", () => {
  it("URL canônica aponta para mercadopagoWebhook", () => {
    assert.equal(
      OFFICIAL_MERCADOPAGO_WEBHOOK_URL,
      "https://southamerica-east1-revalida-cards.cloudfunctions.net/mercadopagoWebhook"
    );
    assert.equal(webhookUrlLooksValid(OFFICIAL_MERCADOPAGO_WEBHOOK_URL), true);
  });

  it("produção ignora skip mesmo com param true", () => {
    const prevProject = process.env.GCLOUD_PROJECT;
    const prevEmu = process.env.FUNCTIONS_EMULATOR;
    process.env.GCLOUD_PROJECT = "revalida-cards";
    delete process.env.FUNCTIONS_EMULATOR;
    try {
      assert.equal(shouldSkipMercadoPagoWebhookSignature("true"), false);
    } finally {
      if (prevProject === undefined) delete process.env.GCLOUD_PROJECT;
      else process.env.GCLOUD_PROJECT = prevProject;
      if (prevEmu === undefined) delete process.env.FUNCTIONS_EMULATOR;
      else process.env.FUNCTIONS_EMULATOR = prevEmu;
    }
  });

  it("emulador pode usar skip", () => {
    const prevEmu = process.env.FUNCTIONS_EMULATOR;
    process.env.FUNCTIONS_EMULATOR = "true";
    try {
      assert.equal(shouldSkipMercadoPagoWebhookSignature("true"), true);
    } finally {
      if (prevEmu === undefined) delete process.env.FUNCTIONS_EMULATOR;
      else process.env.FUNCTIONS_EMULATOR = prevEmu;
    }
  });

  it("normaliza barra final da URL", () => {
    assert.equal(
      normalizeWebhookUrl(`${OFFICIAL_MERCADOPAGO_WEBHOOK_URL}/`),
      OFFICIAL_MERCADOPAGO_WEBHOOK_URL
    );
  });
});
