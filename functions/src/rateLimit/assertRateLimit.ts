import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { extractClientIp } from "./callableContext";
import {
  enforceRateLimits,
  RateLimitExceededError,
} from "./rateLimitService";

export async function assertRateLimitForCallable(
  request: CallableRequest<unknown>,
  action: string
): Promise<void> {
  try {
    await enforceRateLimits({
      action,
      uid: request.auth?.uid,
      ip: extractClientIp(request),
    });
  } catch (err) {
    if (err instanceof RateLimitExceededError) {
      throw new HttpsError("resource-exhausted", err.message);
    }
    throw err;
  }
}
