import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import {
  LIVE_EVENT_PUSH_AUDIENCE,
  PUSH_SEGMENTS,
  PUSH_TYPES,
  type LiveEventPushAudience,
} from "./constants";
import { AudienceResolveCache, type ResolvedAudience } from "./audienceCache";

export type { ResolvedAudience };

/** Mapeia `live_events.pushAudience` → segmento FCM (nunca `all` para live). */
export function liveEventPushSegmentFromEvent(
  pushAudience: string | undefined,
): string {
  const mode = (pushAudience ?? "").trim() as LiveEventPushAudience;
  if (mode === LIVE_EVENT_PUSH_AUDIENCE.platformPublic) {
    return PUSH_SEGMENTS.active7d;
  }
  return PUSH_SEGMENTS.liveEventAudience;
}

/**
 * Público de push para um evento ao vivo: participantes + host (padrão)
 * ou plataforma (`platform_public` explícito no documento do evento).
 */
export async function resolveLiveEventPushAudience(
  eventId: string,
  eventData: Record<string, unknown>,
  cache?: AudienceResolveCache,
): Promise<ResolvedAudience> {
  const c = cache ?? new AudienceResolveCache();
  const segment = liveEventPushSegmentFromEvent(
    eventData.pushAudience as string | undefined,
  );

  if (segment === PUSH_SEGMENTS.liveEventAudience) {
    const db = admin.firestore();
    const parts = await db
      .collection(COLLECTIONS.liveEvents)
      .doc(eventId)
      .collection("participants")
      .limit(2000)
      .get();
    const userIds = new Set(parts.docs.map((p) => p.id));
    const hostId = (eventData.hostId as string)?.trim();
    if (hostId) userIds.add(hostId);
    const ids = [...userIds];
    await c.loadUsers(ids);
    return c.resolveTokensForUserIds(ids, PUSH_TYPES.liveEvent);
  }

  return resolveAudience(segment, PUSH_TYPES.liveEvent, {
    eventId,
    cache: c,
  });
}

export async function resolveAudience(
  segment: string,
  pushType: string,
  options?: { eventId?: string; cache?: AudienceResolveCache },
): Promise<ResolvedAudience> {
  const db = admin.firestore();
  const userIds = new Set<string>();
  const cache = options?.cache ?? new AudienceResolveCache();

  if (
    pushType === PUSH_TYPES.liveEvent &&
    (segment === PUSH_SEGMENTS.all || segment === "all")
  ) {
    console.warn(
      "[push] live_event: segment 'all' não permitido — usando participantes do evento.",
    );
    segment = PUSH_SEGMENTS.liveEventAudience;
  }

  switch (segment) {
    case PUSH_SEGMENTS.premium: {
      const subs = await db
        .collection(COLLECTIONS.subscriptions)
        .where("status", "in", ["active", "trialing"])
        .limit(2000)
        .get();
      for (const doc of subs.docs) {
        const uid = doc.data().userId as string;
        if (uid) userIds.add(uid);
      }
      break;
    }
    case PUSH_SEGMENTS.free: {
      const fcmSnap = await db.collection(COLLECTIONS.fcmUsers).limit(3000).get();
      const premiumIds = new Set<string>();
      const subs = await db
        .collection(COLLECTIONS.subscriptions)
        .where("status", "in", ["active", "trialing"])
        .limit(2000)
        .get();
      for (const doc of subs.docs) {
        const uid = doc.data().userId as string;
        if (uid) premiumIds.add(uid);
      }
      for (const doc of fcmSnap.docs) {
        if (!premiumIds.has(doc.id)) userIds.add(doc.id);
      }
      break;
    }
    case PUSH_SEGMENTS.active7d: {
      const since = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
      );
      const snap = await db
        .collection(COLLECTIONS.fcmUsers)
        .where("lastActiveAt", ">=", since)
        .limit(3000)
        .get();
      for (const doc of snap.docs) userIds.add(doc.id);
      break;
    }
    case PUSH_SEGMENTS.subscriptionExpiring: {
      const now = new Date();
      const in7 = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      const subs = await db
        .collection(COLLECTIONS.subscriptions)
        .where("status", "in", ["active", "trialing"])
        .where("currentPeriodEnd", "<=", admin.firestore.Timestamp.fromDate(in7))
        .where("currentPeriodEnd", ">", admin.firestore.Timestamp.fromDate(now))
        .limit(1000)
        .get();
      for (const doc of subs.docs) {
        const uid = doc.data().userId as string;
        if (uid) userIds.add(uid);
      }
      break;
    }
    case PUSH_SEGMENTS.liveEventAudience: {
      const eventId = options?.eventId?.trim();
      if (eventId) {
        const parts = await db
          .collection(COLLECTIONS.liveEvents)
          .doc(eventId)
          .collection("participants")
          .limit(2000)
          .get();
        for (const p of parts.docs) userIds.add(p.id);
      }
      break;
    }
    case PUSH_SEGMENTS.all:
    default: {
      if (pushType === PUSH_TYPES.liveEvent) {
        console.warn(
          "[push] live_event: segmento amplo bloqueado — use live_event_audience ou platform_public no evento.",
        );
        break;
      }
      const snap = await db.collection(COLLECTIONS.fcmUsers).limit(5000).get();
      for (const doc of snap.docs) userIds.add(doc.id);
      break;
    }
  }

  const ids = [...userIds];
  await cache.loadUsers(ids);
  return cache.resolveTokensForUserIds(ids, pushType);
}
