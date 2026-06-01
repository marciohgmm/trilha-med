import type { CallableRequest } from "firebase-functions/v2/https";

export function extractClientIp(
  request: CallableRequest<unknown>
): string | undefined {
  const raw = request.rawRequest;
  if (!raw) return undefined;

  const forwarded = raw.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    return forwarded.split(",")[0]?.trim();
  }
  if (Array.isArray(forwarded) && forwarded[0]) {
    return String(forwarded[0]).split(",")[0]?.trim();
  }

  const ip = raw.ip ?? raw.socket?.remoteAddress;
  return typeof ip === "string" ? ip : undefined;
}
