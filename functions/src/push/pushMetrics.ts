export function logPushMetrics(
  label: string,
  data: Record<string, string | number | boolean | undefined>,
): void {
  const payload = Object.fromEntries(
    Object.entries(data).filter(([, v]) => v !== undefined),
  );
  console.log(`[push-metrics] ${label}`, JSON.stringify(payload));
}
