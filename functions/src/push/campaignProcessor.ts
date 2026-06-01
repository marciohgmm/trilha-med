import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import { AudienceResolveCache } from "./audienceCache";
import { PUSH_SEGMENTS, PUSH_TYPES } from "./constants";
import { resolveAudience, resolveLiveEventPushAudience } from "./segmentation";
import { sendPushToTokens } from "./fcmSend";
import { logPushMetrics } from "./pushMetrics";

export async function processPushCampaign(campaignId: string): Promise<void> {
  const db = admin.firestore();
  const ref = db.collection(COLLECTIONS.pushCampaigns).doc(campaignId);
  const snap = await ref.get();
  if (!snap.exists) return;

  const data = snap.data()!;
  if (data.status === "sent" || data.status === "sending") return;

  await ref.update({ status: "sending", updatedAt: admin.firestore.FieldValue.serverTimestamp() });

  const cache = new AudienceResolveCache();
  const started = Date.now();
  const pushType = data.type as string;
  const eventId = (data.eventId as string | undefined)?.trim();
  let segment = (data.audienceSegment as string) || PUSH_SEGMENTS.all;

  let audience;
  if (pushType === PUSH_TYPES.liveEvent && eventId) {
    if (segment === PUSH_SEGMENTS.all || segment === "all") {
      segment = PUSH_SEGMENTS.liveEventAudience;
    }
    const eventSnap = await db.collection(COLLECTIONS.liveEvents).doc(eventId).get();
    audience = eventSnap.exists
      ? await resolveLiveEventPushAudience(eventId, eventSnap.data()!, cache)
      : await resolveAudience(PUSH_SEGMENTS.liveEventAudience, pushType, {
          eventId,
          cache,
        });
  } else {
    audience = await resolveAudience(segment, pushType, { eventId, cache });
  }

  logPushMetrics("processPushCampaign", {
    campaignId,
    pushType,
    segment,
    eventId,
    targetUsers: audience.userIds.length,
    tokens: audience.tokens.length,
    userDocReads: cache.getMetrics().userDocReads,
    durationMs: Date.now() - started,
  });

  const result = await sendPushToTokens(audience.tokens, {
    title: data.title as string,
    body: data.body as string,
    type: pushType,
    eventId,
    actionRoute: data.actionRoute as string | undefined,
  });

  await ref.update({
    status: "sent",
    sentCount: result.success,
    failureCount: result.failure,
    targetUserCount: audience.userIds.length,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
