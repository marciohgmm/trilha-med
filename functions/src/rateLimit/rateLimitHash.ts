import * as crypto from "crypto";

function salt(envKey: string, fallback: string): string {
  return process.env[envKey]?.trim() || fallback;
}

export function hashIp(ip: string): string {
  const value = salt("RATE_LIMIT_IP_SALT", "revalida-rate-limit-ip");
  return crypto
    .createHash("sha256")
    .update(`${value}:${ip.trim()}`)
    .digest("hex")
    .slice(0, 40);
}

export function hashEmail(email: string): string {
  const normalized = email.trim().toLowerCase();
  const value = salt("RATE_LIMIT_EMAIL_SALT", "revalida-rate-limit-email");
  return crypto
    .createHash("sha256")
    .update(`${value}:${normalized}`)
    .digest("hex")
    .slice(0, 40);
}
