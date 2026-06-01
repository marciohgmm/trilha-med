import type { CallableOptions } from "firebase-functions/v2/https";

const REGION = "southamerica-east1" as const;

type AppCheckCallableExtra = Omit<CallableOptions, "region" | "enforceAppCheck">;

/**
 * Opções padrão para callables expostas ao app Flutter.
 * Webhook HTTP e jobs agendados não usam este helper.
 */
export function appCheckCallableOptions(
  extra: AppCheckCallableExtra = {},
  opts?: { consumeAppCheckToken?: boolean }
): CallableOptions {
  return {
    region: REGION,
    enforceAppCheck: true,
    ...(opts?.consumeAppCheckToken ? { consumeAppCheckToken: true } : {}),
    ...extra,
  };
}
