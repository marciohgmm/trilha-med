import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import { PUSH_TYPES } from "./constants";
import {
  sendPushToTokens,
  getTokensForUser,
  userAllowsPushType,
} from "./fcmSend";
import { AudienceResolveCache } from "./audienceCache";
import { logPushMetrics } from "./pushMetrics";
import { resolveLiveEventPushAudience } from "./segmentation";

async function sendDigestToActiveUsers(
  type: string,
  title: string,
  body: string,
  actionRoute?: string,
): Promise<number> {
  const db = admin.firestore();
  const since = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 14 * 24 * 60 * 60 * 1000),
  );
  const snap = await db
    .collection(COLLECTIONS.fcmUsers)
    .where("lastActiveAt", ">=", since)
    .limit(2000)
    .get();

  const tokens: string[] = [];
  for (const doc of snap.docs) {
    const uid = doc.id;
    const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
    const prefs = userSnap.data()?.notificationPrefs as Record<string, unknown> | undefined;
    if (!userAllowsPushType(prefs, type)) continue;
    tokens.push(...(await getTokensForUser(uid)));
  }

  const unique = [...new Set(tokens)];
  if (unique.length === 0) return 0;
  const r = await sendPushToTokens(unique, { title, body, type, actionRoute });
  return r.success;
}

/** Revisão de flashcards — diário 09:00 BRT. */
export const pushFlashcardReviewScheduled = onSchedule(
  {
    schedule: "0 12 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const sent = await sendDigestToActiveUsers(
      PUSH_TYPES.flashcardReview,
      "Hora de revisar flashcards",
      "Mantenha sua sequência de estudos — abra o app e revise alguns cards.",
    );
    console.log(`pushFlashcardReview: ${sent} tokens`);
  },
);

/** Cronograma atrasado — diário 08:00 BRT. */
export const pushCronogramaOverdueScheduled = onSchedule(
  {
    schedule: "0 11 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const db = admin.firestore();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTs = admin.firestore.Timestamp.fromDate(today);

    const overdue = await db
      .collectionGroup("cronograma_itens")
      .where("dataEstudo", "<", todayTs)
      .where("concluidoHoje", "==", false)
      .limit(400)
      .get();

    const userIds = new Set<string>();
    for (const doc of overdue.docs) {
      const parts = doc.ref.path.split("/");
      const userIndex = parts.indexOf("users");
      if (userIndex >= 0 && parts[userIndex + 1]) {
        userIds.add(parts[userIndex + 1]);
      }
    }

    const tokens: string[] = [];
    for (const uid of userIds) {
      const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
      const prefs = userSnap.data()?.notificationPrefs as Record<string, unknown> | undefined;
      if (!userAllowsPushType(prefs, PUSH_TYPES.cronogramaOverdue)) continue;
      tokens.push(...(await getTokensForUser(uid)));
    }

    const unique = [...new Set(tokens)];
    if (unique.length > 0) {
      await sendPushToTokens(unique, {
        title: "Cronograma atrasado",
        body: "Você tem itens pendentes no cronograma. Organize seu dia de estudos!",
        type: PUSH_TYPES.cronogramaOverdue,
      });
    }
    console.log(`pushCronogramaOverdue: ${unique.length} tokens, ${userIds.size} users`);
  },
);

/** Simulados — segundas 10:00 BRT. */
export const pushSimuladoAvailableScheduled = onSchedule(
  {
    schedule: "0 13 * * 1",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const sent = await sendDigestToActiveUsers(
      PUSH_TYPES.simuladoAvailable,
      "Simulado disponível",
      "Treine com um simulado personalizado esta semana.",
      "simulado",
    );
    console.log(`pushSimuladoAvailable: ${sent}`);
  },
);

/** Renovação de assinatura — diário 10:00 BRT. */
export const pushSubscriptionRenewalScheduled = onSchedule(
  {
    schedule: "0 13 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const in7 = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    const subs = await db
      .collection(COLLECTIONS.subscriptions)
      .where("status", "in", ["active", "trialing"])
      .where("currentPeriodEnd", "<=", admin.firestore.Timestamp.fromDate(in7))
      .where("currentPeriodEnd", ">", admin.firestore.Timestamp.fromDate(now))
      .limit(500)
      .get();

    const tokens: string[] = [];
    for (const doc of subs.docs) {
      const uid = doc.data().userId as string;
      if (!uid) continue;
      const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
      const prefs = userSnap.data()?.notificationPrefs as Record<string, unknown> | undefined;
      if (!userAllowsPushType(prefs, PUSH_TYPES.subscriptionRenewal)) continue;
      tokens.push(...(await getTokensForUser(uid)));
    }

    const unique = [...new Set(tokens)];
    if (unique.length > 0) {
      await sendPushToTokens(unique, {
        title: "Renovação da assinatura",
        body: "Sua assinatura Premium renova em breve. Confira em Minha Assinatura.",
        type: PUSH_TYPES.subscriptionRenewal,
        actionRoute: "subscription",
      });
    }
    console.log(`pushSubscriptionRenewal: ${unique.length} tokens`);
  },
);

/** Eventos ao vivo — a cada 15 min, lembrete 30 min antes. */
export const pushLiveEventsScheduled = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const in30 = new Date(now.getTime() + 30 * 60 * 1000);
    const in45 = new Date(now.getTime() + 45 * 60 * 1000);

    const snap = await db
      .collection(COLLECTIONS.liveEvents)
      .where("scheduledAt", ">=", admin.firestore.Timestamp.fromDate(in30))
      .where("scheduledAt", "<=", admin.firestore.Timestamp.fromDate(in45))
      .limit(20)
      .get();

    const cache = new AudienceResolveCache();
    const started = Date.now();
    let eventsProcessed = 0;
    let totalTokens = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      if (data.pushReminderSent === true) continue;

      const title = (data.title as string) || "Evento ao vivo";
      const audience = await resolveLiveEventPushAudience(doc.id, data, cache);

      if (audience.tokens.length === 0) {
        console.log(
          `pushLiveEvents: ${doc.id} — sem destinatários (audience=${data.pushAudience ?? "participants"})`,
        );
        await doc.ref.update({ pushReminderSent: true });
        continue;
      }

      await sendPushToTokens(audience.tokens, {
        title: "Evento começa em breve",
        body: `"${title}" inicia em cerca de 30 minutos. Entre no app!`,
        type: PUSH_TYPES.liveEvent,
        eventId: doc.id,
        actionRoute: "live_event",
      });

      await doc.ref.update({ pushReminderSent: true });
      eventsProcessed += 1;
      totalTokens += audience.tokens.length;
    }

    logPushMetrics("pushLiveEventsScheduled", {
      eventsQueried: snap.size,
      eventsProcessed,
      totalTokens,
      userDocReads: cache.getMetrics().userDocReads,
      durationMs: Date.now() - started,
    });
  },
);
