import * as admin from "firebase-admin";
import { COLLECTIONS } from "./constants";

export const ANALYTICS_EVENTS = {
  login: "login",
  signUp: "sign_up",
  sessionStart: "session_start",
  paywallView: "paywall_view",
  checkoutStart: "checkout_start",
  purchaseApproved: "purchase_approved",
  purchaseCancelled: "purchase_cancelled",
} as const;

const MIRRORED_EVENTS = new Set<string>(Object.values(ANALYTICS_EVENTS));

export const ANALYTICS_DAILY_COLLECTION = "platform_analytics_daily";
export const RAW_RETENTION_DAYS = 90;

function dayKey(date: Date): string {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function dailyIncrements(
  eventName: string,
  parameters: Record<string, string | number> = {},
): Record<string, admin.firestore.FieldValue | admin.firestore.Timestamp> {
  const updates: Record<string, admin.firestore.FieldValue | admin.firestore.Timestamp> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  switch (eventName) {
    case ANALYTICS_EVENTS.signUp:
      updates.signups = admin.firestore.FieldValue.increment(1);
      break;
    case ANALYTICS_EVENTS.login:
      updates.logins = admin.firestore.FieldValue.increment(1);
      break;
    case ANALYTICS_EVENTS.sessionStart:
      updates.sessions = admin.firestore.FieldValue.increment(1);
      break;
    case ANALYTICS_EVENTS.paywallView:
      updates.paywallViews = admin.firestore.FieldValue.increment(1);
      break;
    case ANALYTICS_EVENTS.checkoutStart:
      updates.checkoutStarts = admin.firestore.FieldValue.increment(1);
      break;
    case ANALYTICS_EVENTS.purchaseApproved:
      updates.purchases = admin.firestore.FieldValue.increment(1);
      if (typeof parameters.amount === "number") {
        updates.revenue = admin.firestore.FieldValue.increment(parameters.amount);
      }
      break;
    case ANALYTICS_EVENTS.purchaseCancelled:
      updates.purchasesCancelled = admin.firestore.FieldValue.increment(1);
      break;
    default:
      break;
  }

  return updates;
}

/** Espelha evento crítico + incrementa agregado diário (Admin SDK). */
export async function mirrorAnalyticsEvent(
  eventName: string,
  userId: string,
  parameters: Record<string, string | number> = {},
): Promise<void> {
  if (!MIRRORED_EVENTS.has(eventName)) {
    console.log(`[analytics] skip mirror (not critical): ${eventName}`);
    return;
  }

  const db = admin.firestore();
  const now = new Date();
  const expireAt = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + RAW_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  );
  const today = dayKey(now);
  const batch = db.batch();

  const eventRef = db.collection(COLLECTIONS.analyticsEvents).doc();
  batch.set(eventRef, {
    eventName,
    userId,
    parameters,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expireAt,
  });

  const dailyRef = db.collection(ANALYTICS_DAILY_COLLECTION).doc(today);
  const increments = dailyIncrements(eventName, parameters);
  if (Object.keys(increments).length > 1) {
    batch.set(dailyRef, increments, { merge: true });
  }

  if (eventName === ANALYTICS_EVENTS.sessionStart) {
    batch.set(
      dailyRef.collection("active_users").doc(userId),
      { at: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
  }

  await batch.commit();
}
