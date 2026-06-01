import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import { nextWindowState } from "./rateLimitCore";
import {
  RATE_LIMIT_RULES,
  RATE_LIMIT_USER_MESSAGE,
  type RateLimitRule,
  type RateLimitScope,
} from "./rateLimitConfig";
import { hashEmail, hashIp } from "./rateLimitHash";
import { logRateLimitAudit } from "./rateLimitAudit";

const db = () => admin.firestore();

export class RateLimitExceededError extends Error {
  readonly action: string;
  readonly reason: string;

  constructor(action: string, reason: string) {
    super(RATE_LIMIT_USER_MESSAGE);
    this.name = "RateLimitExceededError";
    this.action = action;
    this.reason = reason;
  }
}

export function buildSubjectKey(scope: RateLimitScope, raw: string): string {
  switch (scope) {
    case "uid":
      return `uid:${raw}`;
    case "ip":
      return `ip:${hashIp(raw)}`;
    case "email":
      return `email:${hashEmail(raw)}`;
    default:
      return `${scope}:${raw}`;
  }
}

export function buildRateLimitDocId(action: string, subjectKey: string): string {
  const id = `${action}__${subjectKey}`;
  return id.length > 500 ? id.slice(0, 500) : id;
}

type AcquireParams = {
  action: string;
  rule: RateLimitRule;
  subjectValue: string;
  uid?: string;
  ipRaw?: string;
};

async function tryAcquireOne(params: AcquireParams): Promise<void> {
  const subjectKey = buildSubjectKey(params.rule.scope, params.subjectValue);
  const docId = buildRateLimitDocId(params.action, subjectKey);
  const ref = db().collection(COLLECTIONS.rateLimits).doc(docId);
  const nowMs = Date.now();
  const ipHash =
    params.rule.scope === "ip"
      ? hashIp(params.subjectValue)
      : params.ipRaw
        ? hashIp(params.ipRaw)
        : undefined;

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const prevStart = data?.windowStart?.toMillis?.() as number | undefined;
    const prevCount = (data?.count as number | undefined) ?? 0;

    const tick = nextWindowState(
      nowMs,
      prevStart ?? null,
      prevCount,
      params.rule.windowMs,
      params.rule.maxRequests
    );

    if (!tick.allowed) {
      throw new RateLimitExceededError(
        params.action,
        `limit:${params.rule.scope}:${params.rule.maxRequests}/${params.rule.windowMs}ms`
      );
    }

    tx.set(
      ref,
      {
        uid: params.rule.scope === "uid" ? params.subjectValue : params.uid ?? null,
        action: params.action,
        windowStart: admin.firestore.Timestamp.fromMillis(tick.windowStartMs),
        count: tick.count,
        lastRequest: admin.firestore.FieldValue.serverTimestamp(),
        ...(ipHash ? { ipHash } : {}),
        subjectKey,
      },
      { merge: true }
    );
  });
}

export type EnforceRateLimitsParams = {
  action: string;
  uid?: string;
  ip?: string;
  email?: string;
};

export async function enforceRateLimits(
  params: EnforceRateLimitsParams
): Promise<void> {
  const rules = RATE_LIMIT_RULES[params.action];
  if (!rules?.length) return;

  for (const rule of rules) {
    let subjectValue: string | undefined;
    switch (rule.scope) {
      case "uid":
        subjectValue = params.uid;
        break;
      case "ip":
        subjectValue = params.ip;
        break;
      case "email":
        subjectValue = params.email;
        break;
    }
    if (!subjectValue) continue;

    try {
      await tryAcquireOne({
        action: params.action,
        rule,
        subjectValue,
        uid: params.uid,
        ipRaw: params.ip,
      });
    } catch (err) {
      if (err instanceof RateLimitExceededError) {
        await logRateLimitAudit({
          action: params.action,
          uid: params.uid,
          blocked: true,
          reason: err.reason,
          subjectKey: buildSubjectKey(rule.scope, subjectValue),
          ipHash: params.ip ? hashIp(params.ip) : undefined,
        });
        throw err;
      }
      throw err;
    }
  }
}
