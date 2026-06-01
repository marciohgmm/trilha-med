import * as crypto from "crypto";

export type WebhookSignatureValidation = {
  valid: boolean;
  reason: string;
  ts?: string;
  requestId?: string;
};

/** Extrai ts e v1 do header x-signature (formato: ts=...,v1=...). */
export function parseMercadoPagoSignatureHeader(
  header: string | undefined
): { ts: string; v1: string } | null {
  if (!header?.trim()) return null;
  let ts = "";
  let v1 = "";
  for (const part of header.split(",")) {
    const [key, ...rest] = part.trim().split("=");
    const value = rest.join("=").trim();
    if (key === "ts") ts = value;
    if (key === "v1") v1 = value;
  }
  if (!ts || !v1) return null;
  return { ts, v1 };
}

/**
 * Manifest oficial Mercado Pago:
 * id:[data.id];request-id:[x-request-id];ts:[ts];
 * (omitir partes ausentes)
 */
export function buildMercadoPagoSignatureManifest(params: {
  dataId: string;
  requestId?: string;
  ts: string;
}): string {
  const parts: string[] = [`id:${params.dataId}`];
  if (params.requestId?.trim()) {
    parts.push(`request-id:${params.requestId.trim()}`);
  }
  parts.push(`ts:${params.ts}`);
  return `${parts.join(";")};`;
}

export function computeMercadoPagoSignature(
  secret: string,
  manifest: string
): string {
  return crypto.createHmac("sha256", secret).update(manifest).digest("hex");
}

/** Comparação timing-safe. */
export function signaturesMatch(expected: string, received: string): boolean {
  try {
    const a = Buffer.from(expected, "hex");
    const b = Buffer.from(received, "hex");
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

const DEFAULT_MAX_AGE_MS = 10 * 60 * 1000;

/**
 * Valida x-signature do webhook Mercado Pago.
 * @see https://www.mercadopago.com.br/developers/en/docs/your-integrations/notifications/webhooks
 */
export function validateMercadoPagoWebhookSignature(params: {
  secret: string;
  xSignature: string | undefined;
  xRequestId: string | undefined;
  dataId: string;
  maxAgeMs?: number;
  nowMs?: number;
}): WebhookSignatureValidation {
  const { secret, xSignature, xRequestId, dataId } = params;
  const maxAgeMs = params.maxAgeMs ?? DEFAULT_MAX_AGE_MS;
  const nowMs = params.nowMs ?? Date.now();

  if (!secret?.trim()) {
    return { valid: false, reason: "webhook_secret_missing" };
  }
  if (!dataId?.trim()) {
    return { valid: false, reason: "data_id_missing" };
  }

  const parsed = parseMercadoPagoSignatureHeader(xSignature);
  if (!parsed) {
    return { valid: false, reason: "x_signature_malformed" };
  }

  const tsMs = Number(parsed.ts) * 1000;
  if (!Number.isFinite(tsMs)) {
    return { valid: false, reason: "timestamp_invalid" };
  }
  if (Math.abs(nowMs - tsMs) > maxAgeMs) {
    return {
      valid: false,
      reason: "timestamp_out_of_window",
      ts: parsed.ts,
      requestId: xRequestId,
    };
  }

  const manifest = buildMercadoPagoSignatureManifest({
    dataId: dataId.trim(),
    requestId: xRequestId,
    ts: parsed.ts,
  });
  const expected = computeMercadoPagoSignature(secret.trim(), manifest);
  if (!signaturesMatch(expected, parsed.v1)) {
    return {
      valid: false,
      reason: "signature_mismatch",
      ts: parsed.ts,
      requestId: xRequestId,
    };
  }

  return {
    valid: true,
    reason: "ok",
    ts: parsed.ts,
    requestId: xRequestId,
  };
}
