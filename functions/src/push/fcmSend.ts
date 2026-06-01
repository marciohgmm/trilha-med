import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";

const BATCH_SIZE = 500;

export interface PushPayload {
  title: string;
  body: string;
  type: string;
  eventId?: string;
  actionRoute?: string;
}

export async function sendPushToTokens(
  tokens: string[],
  payload: PushPayload,
): Promise<{ success: number; failure: number }> {
  if (tokens.length === 0) return { success: 0, failure: 0 };
  let success = 0;
  let failure = 0;
  const messaging = admin.messaging();
  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const chunk = tokens.slice(i, i + BATCH_SIZE);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title: payload.title, body: payload.body },
      data: {
        type: payload.type,
        ...(payload.eventId ? { eventId: payload.eventId } : {}),
        ...(payload.actionRoute ? { actionRoute: payload.actionRoute } : {}),
      },
      android: {
        priority: "high",
        notification: { channelId: "trilhamed_default" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });
    success += response.successCount;
    failure += response.failureCount;
  }
  return { success, failure };
}

export function extractFcmTokens(
  userData: Record<string, unknown> | null | undefined,
): string[] {
  if (!userData) return [];
  const fcmTokens = userData.fcmTokens as Record<string, unknown> | undefined;
  if (!fcmTokens) return [];
  return Object.keys(fcmTokens).filter((t) => t.length > 0);
}

export async function getTokensForUser(userId: string): Promise<string[]> {
  const db = admin.firestore();
  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  return extractFcmTokens(
    userSnap.exists ? (userSnap.data() as Record<string, unknown>) : null,
  );
}

export function userAllowsPushType(
  notificationPrefs: Record<string, unknown> | undefined,
  type: string,
): boolean {
  if (!notificationPrefs) return true;
  return notificationPrefs[type] !== false;
}
