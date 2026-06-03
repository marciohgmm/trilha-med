import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import { assertAppAdmin } from "./adminAuth";
import { processPushCampaign } from "./campaignProcessor";
import { resolveLiveEventPushAudience } from "./segmentation";
import { sendPushToTokens } from "./fcmSend";
import { AudienceResolveCache } from "./audienceCache";
import { PUSH_SEGMENTS, PUSH_TYPES } from "./constants";
import { logPushMetrics } from "./pushMetrics";
import { appCheckCallableOptions } from "../callableOptions";
import { assertRateLimitForCallable } from "../rateLimit/assertRateLimit";
import { RATE_LIMIT_ACTIONS } from "../rateLimit/rateLimitConfig";

const PARTICIPANT_STATUS_ELIMINATED = "eliminated";

/** Host do evento ou administrador da plataforma. */
async function assertLiveEventHostOrAdmin(
  uid: string,
  email: string | null | undefined,
  eventId: string,
): Promise<void> {
  const db = admin.firestore();
  const eventSnap = await db.collection(COLLECTIONS.liveEvents).doc(eventId).get();
  if (!eventSnap.exists) {
    throw new HttpsError("not-found", "Evento não encontrado.");
  }
  const hostId = (eventSnap.data()?.hostId as string) ?? "";
  if (hostId !== uid) {
    await assertAppAdmin(uid, email);
  }
}

/** Participante alvo deve existir no evento com status eliminated (anti-abuso de push). */
async function assertLiveEventParticipantEliminated(
  eventId: string,
  targetUserId: string,
): Promise<void> {
  const db = admin.firestore();
  const partSnap = await db
    .collection(COLLECTIONS.liveEvents)
    .doc(eventId)
    .collection("participants")
    .doc(targetUserId)
    .get();

  if (!partSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Participante não encontrado neste evento.",
    );
  }

  const status = (partSnap.data()?.status as string) ?? "";
  if (status !== PARTICIPANT_STATUS_ELIMINATED) {
    throw new HttpsError(
      "permission-denied",
      "Notificação de eliminação exige participante com status eliminated.",
    );
  }
}

export const registerFcmToken = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário.");

    await assertRateLimitForCallable(request, RATE_LIMIT_ACTIONS.registerFcm);

    const token = (request.data?.token as string)?.trim();
    const platform = (request.data?.platform as string)?.trim() || "unknown";
    if (!token) throw new HttpsError("invalid-argument", "token obrigatório.");

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.collection(COLLECTIONS.users).doc(uid).set(
      {
        fcmTokens: {
          [token]: { platform, updatedAt: now },
        },
        updatedAt: now,
      },
      { merge: true },
    );

    await db.collection(COLLECTIONS.fcmUsers).doc(uid).set(
      {
        userId: uid,
        lastActiveAt: now,
        lastTokenAt: now,
        updatedAt: now,
      },
      { merge: true },
    );

    const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
    const tokens = userSnap.data()?.fcmTokens as Record<string, unknown> | undefined;
    const count = tokens ? Object.keys(tokens).length : 1;
    await db.collection(COLLECTIONS.fcmUsers).doc(uid).set({ tokenCount: count }, { merge: true });

    return { ok: true };
  },
);

export const createPushCampaign = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário.");
    await assertAppAdmin(uid, request.auth?.token?.email);
    await assertRateLimitForCallable(request, RATE_LIMIT_ACTIONS.pushCampaign);

    const title = (request.data?.title as string)?.trim();
    const body = (request.data?.body as string)?.trim();
    const type = (request.data?.type as string)?.trim();
    let audienceSegment =
      (request.data?.audienceSegment as string)?.trim() || PUSH_SEGMENTS.all;
    const eventId = (request.data?.eventId as string)?.trim();
    if (
      type === PUSH_TYPES.liveEvent &&
      eventId &&
      (audienceSegment === PUSH_SEGMENTS.all || audienceSegment === "all")
    ) {
      audienceSegment = PUSH_SEGMENTS.liveEventAudience;
    }
    const actionRoute = (request.data?.actionRoute as string)?.trim();

    if (!title || !body || !type) {
      throw new HttpsError("invalid-argument", "title, body e type são obrigatórios.");
    }

    const db = admin.firestore();
    const doc = await db.collection(COLLECTIONS.pushCampaigns).add({
      title,
      body,
      type,
      audienceSegment,
      ...(eventId ? { eventId } : {}),
      ...(actionRoute ? { actionRoute } : {}),
      status: "queued",
      sentCount: 0,
      failureCount: 0,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { campaignId: doc.id };
  },
);

export const onPushCampaignCreated = onDocumentCreated(
  {
    document: `${COLLECTIONS.pushCampaigns}/{campaignId}`,
    region: "southamerica-east1",
  },
  async (event) => {
    const campaignId = event.params.campaignId;
    await processPushCampaign(campaignId);
  },
);

export const notifyLiveEventBroadcast = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário.");

    await assertRateLimitForCallable(
      request,
      RATE_LIMIT_ACTIONS.notifyLiveBroadcast,
    );

    const eventId = (request.data?.eventId as string)?.trim();
    const phase = (request.data?.phase as string)?.trim() || "live";
    if (!eventId) throw new HttpsError("invalid-argument", "eventId obrigatório.");

    const db = admin.firestore();
    const eventSnap = await db.collection(COLLECTIONS.liveEvents).doc(eventId).get();
    if (!eventSnap.exists) throw new HttpsError("not-found", "Evento não encontrado.");

    const event = eventSnap.data()!;
    const hostId = event.hostId as string;
    if (hostId !== uid) await assertAppAdmin(uid, request.auth?.token?.email);

    const title =
      phase === "ended"
        ? "Evento encerrado"
        : phase === "live"
          ? "Evento ao vivo!"
          : "Atualização do evento";
    const body = (event.title as string) || "Confira o evento ao vivo no app.";

    const cache = new AudienceResolveCache();
    const started = Date.now();
    const audience = await resolveLiveEventPushAudience(eventId, event, cache);
    if (audience.tokens.length === 0) {
      return { sent: 0, warning: "Nenhum destinatário para o público configurado." };
    }

    logPushMetrics("notifyLiveEventBroadcast", {
      eventId,
      phase,
      pushAudience: (event.pushAudience as string) ?? "participants",
      targetUsers: audience.userIds.length,
      tokens: audience.tokens.length,
      userDocReads: cache.getMetrics().userDocReads,
      durationMs: Date.now() - started,
    });

    await sendPushToTokens(audience.tokens, {
      title,
      body,
      type: PUSH_TYPES.liveEvent,
      eventId,
      actionRoute: "live_event",
    });

    return {
      sent: audience.tokens.length,
      audience: (event.pushAudience as string) ?? "participants",
    };
  },
);

export const notifyLiveEventUser = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário.");

    const userId = (request.data?.userId as string)?.trim();
    const eventId = (request.data?.eventId as string)?.trim();
    if (!userId || !eventId) {
      throw new HttpsError("invalid-argument", "userId e eventId obrigatórios.");
    }

    const db = admin.firestore();
    const eventSnap = await db.collection(COLLECTIONS.liveEvents).doc(eventId).get();
    if (!eventSnap.exists) {
      throw new HttpsError("not-found", "Evento não encontrado.");
    }

    const hostId = (eventSnap.data()?.hostId as string) ?? "";
    const isHost = hostId === uid;
    let isAdmin = false;
    if (!isHost) {
      try {
        await assertAppAdmin(uid, request.auth?.token?.email);
        isAdmin = true;
      } catch {
        throw new HttpsError(
          "permission-denied",
          "Apenas o host do evento ou um administrador pode enviar esta notificação.",
        );
      }
    }

    if (!isAdmin) {
      await assertLiveEventParticipantEliminated(eventId, userId);
    }

    const { getTokensForUser } = await import("./fcmSend");
    const tokens = await getTokensForUser(userId);
    if (tokens.length === 0) {
      console.warn(
        `[notifyLiveEventUser] sem tokens FCM userId=${userId} eventId=${eventId}`,
      );
    }
    await sendPushToTokens(tokens, {
      title: "Você foi eliminado",
      body: "Não desanime — há mais eventos em breve!",
      type: PUSH_TYPES.liveEvent,
      eventId,
    });
    return { ok: true, sent: tokens.length };
  },
);

export const scheduleLiveEventReminders = onCall(
  appCheckCallableOptions(),
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário.");

    const eventId = (request.data?.eventId as string)?.trim();
    if (!eventId) throw new HttpsError("invalid-argument", "eventId obrigatório.");

    await assertLiveEventHostOrAdmin(uid, request.auth?.token?.email, eventId);

    const db = admin.firestore();
    await db.collection(COLLECTIONS.liveEvents).doc(eventId).set(
      { pushReminderScheduled: true },
      { merge: true },
    );
    return { ok: true };
  },
);
