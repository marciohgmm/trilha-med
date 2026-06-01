import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "./constants";
import { RAW_RETENTION_DAYS } from "./analyticsService";

const PURGE_BATCH = 400;

/** Remove eventos brutos expirados (retenção 90 dias). Agregados diários permanecem. */
export const purgeAnalyticsEventsScheduled = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - RAW_RETENTION_DAYS * 24 * 60 * 60 * 1000),
    );

    let deleted = 0;
    while (true) {
      const snap = await db
        .collection(COLLECTIONS.analyticsEvents)
        .where("createdAt", "<", cutoff)
        .limit(PURGE_BATCH)
        .get();

      if (snap.empty) break;

      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      deleted += snap.size;

      if (snap.size < PURGE_BATCH) break;
    }

    console.log(
      `[analytics-purge] deleted ${deleted} raw events older than ${RAW_RETENTION_DAYS}d`,
    );
  },
);

/** Sincroniza campo `dau` nos agregados diários (contagem de active_users). */
export const syncAnalyticsDauScheduled = onSchedule(
  {
    schedule: "30 4 * * *",
    timeZone: "America/Sao_Paulo",
    region: "southamerica-east1",
  },
  async () => {
    const db = admin.firestore();
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const y = yesterday.getUTCFullYear();
    const m = String(yesterday.getUTCMonth() + 1).padStart(2, "0");
    const d = String(yesterday.getUTCDate()).padStart(2, "0");
    const dayId = `${y}-${m}-${d}`;

    const activeCol = db
      .collection("platform_analytics_daily")
      .doc(dayId)
      .collection("active_users");

    const countSnap = await activeCol.count().get();
    const dau = countSnap.data().count;

    await db.collection("platform_analytics_daily").doc(dayId).set(
      {
        dau,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    console.log(`[analytics-dau] ${dayId} dau=${dau}`);
  },
);
