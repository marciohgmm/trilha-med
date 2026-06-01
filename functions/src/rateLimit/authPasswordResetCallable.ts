import { onCall, HttpsError } from "firebase-functions/v2/https";
import { appCheckCallableOptions } from "../callableOptions";
import { extractClientIp } from "./callableContext";
import { RATE_LIMIT_ACTIONS } from "./rateLimitConfig";
import {
  enforceRateLimits,
  RateLimitExceededError,
} from "./rateLimitService";

/**
 * Pré-verificação de rate limit antes de `sendPasswordResetEmail` no cliente.
 * Não envia e-mail — só conta a tentativa (5/h por e-mail).
 * UX inalterada: mesma tela; uma chamada rápida antes do SDK Auth.
 */
export const rateLimitPasswordReset = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const email = (request.data?.email as string)?.trim();
    if (!email) {
      throw new HttpsError("invalid-argument", "email obrigatório.");
    }

    try {
      await enforceRateLimits({
        action: RATE_LIMIT_ACTIONS.authResetPassword,
        email,
        ip: extractClientIp(request),
      });
    } catch (err) {
      if (err instanceof RateLimitExceededError) {
        throw new HttpsError("resource-exhausted", err.message);
      }
      throw err;
    }

    return { ok: true };
  }
);
