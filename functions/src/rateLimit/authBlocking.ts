import {
  beforeUserCreated,
  beforeUserSignedIn,
  HttpsError,
  type AuthBlockingEvent,
} from "firebase-functions/v2/identity";
import { RATE_LIMIT_ACTIONS } from "./rateLimitConfig";
import {
  enforceRateLimits,
  RateLimitExceededError,
} from "./rateLimitService";

const REGION = "southamerica-east1";

function clientIpFromAuthEvent(event: AuthBlockingEvent): string | undefined {
  const ip = (event as AuthBlockingEvent & { ipAddress?: string }).ipAddress;
  return typeof ip === "string" ? ip : undefined;
}

async function enforceAuthRateLimit(params: {
  action: string;
  email?: string;
  ip?: string;
}): Promise<void> {
  if (!params.email && !params.ip) return;
  try {
    await enforceRateLimits({
      action: params.action,
      email: params.email,
      ip: params.ip,
    });
  } catch (err) {
    if (err instanceof RateLimitExceededError) {
      throw new HttpsError("resource-exhausted", err.message);
    }
    throw err;
  }
}

/** Login — 20/h por e-mail, 40/h por IP. */
export const rateLimitBeforeSignIn = beforeUserSignedIn(
  { region: REGION },
  async (event) => {
    await enforceAuthRateLimit({
      action: RATE_LIMIT_ACTIONS.authLogin,
      email: event.data.email,
      ip: clientIpFromAuthEvent(event),
    });
  }
);

/** Cadastro — 10/h por e-mail, 20/h por IP. */
export const rateLimitBeforeCreate = beforeUserCreated(
  { region: REGION },
  async (event) => {
    await enforceAuthRateLimit({
      action: RATE_LIMIT_ACTIONS.authSignUp,
      email: event.data.email,
      ip: clientIpFromAuthEvent(event),
    });
  }
);
