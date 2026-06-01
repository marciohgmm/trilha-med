/** Logs estruturados para diagnóstico de assinaturas / Mercado Pago. */
export function logSubscription(
  event: string,
  data: Record<string, unknown> = {}
): void {
  console.log(
    JSON.stringify({
      tag: "subscription",
      event,
      ts: new Date().toISOString(),
      ...data,
    })
  );
}

export function logSubscriptionError(
  event: string,
  error: unknown,
  data: Record<string, unknown> = {}
): void {
  const message = error instanceof Error ? error.message : String(error);
  console.error(
    JSON.stringify({
      tag: "subscription",
      level: "error",
      event,
      message,
      ts: new Date().toISOString(),
      ...data,
    })
  );
}
