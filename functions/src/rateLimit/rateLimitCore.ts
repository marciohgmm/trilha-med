/** Lógica pura de janela fixa (testável sem Firestore). */
export type WindowTickResult = {
  allowed: boolean;
  windowStartMs: number;
  count: number;
};

export function nextWindowState(
  nowMs: number,
  prevWindowStartMs: number | null,
  prevCount: number,
  windowMs: number,
  maxRequests: number
): WindowTickResult {
  const expired =
    prevWindowStartMs == null || nowMs - prevWindowStartMs >= windowMs;

  if (expired) {
    return { allowed: true, windowStartMs: nowMs, count: 1 };
  }

  const nextCount = prevCount + 1;
  if (nextCount > maxRequests) {
    return {
      allowed: false,
      windowStartMs: prevWindowStartMs,
      count: nextCount,
    };
  }

  return {
    allowed: true,
    windowStartMs: prevWindowStartMs,
    count: nextCount,
  };
}
