import type { CallableOptions } from "firebase-functions/v2/https";

const REGION = "southamerica-east1" as const;

type AppCheckCallableExtra = Omit<
  CallableOptions,
  "region" | "enforceAppCheck" | "invoker"
>;

/**
 * Opções padrão para callables expostas ao app Flutter.
 * Webhook HTTP e jobs agendados não usam este helper.
 *
 * `invoker: public` — Cloud Run aceita chamadas do cliente; Auth/App Check
 * continuam validados pelo protocolo callable (evita `unauthenticated` genérico).
 */
export function appCheckCallableOptions(
  extra: AppCheckCallableExtra = {},
  opts?: { consumeAppCheckToken?: boolean }
): CallableOptions {
  return {
    region: REGION,
    enforceAppCheck: true,
    invoker: "public",
    ...(opts?.consumeAppCheckToken ? { consumeAppCheckToken: true } : {}),
    ...extra,
  };
}
