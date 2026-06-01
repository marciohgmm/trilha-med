import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";
import { extractFcmTokens, userAllowsPushType } from "./fcmSend";

export interface ResolvedAudience {
  userIds: string[];
  tokens: string[];
}

export interface AudienceCacheMetrics {
  userDocReads: number;
  usersResolved: number;
  tokensCollected: number;
}

const GET_ALL_CHUNK = 10;

export class AudienceResolveCache {
  private readonly userData = new Map<string, Record<string, unknown> | null>();
  private readonly metrics: AudienceCacheMetrics = {
    userDocReads: 0,
    usersResolved: 0,
    tokensCollected: 0,
  };

  getMetrics(): AudienceCacheMetrics {
    return { ...this.metrics };
  }

  async loadUsers(userIds: string[]): Promise<void> {
    const db = admin.firestore();
    const missing = userIds.filter((id) => id && !this.userData.has(id));
    if (missing.length === 0) return;

    for (let i = 0; i < missing.length; i += GET_ALL_CHUNK) {
      const chunk = missing.slice(i, i + GET_ALL_CHUNK);
      const refs = chunk.map((id) => db.collection(COLLECTIONS.users).doc(id));
      const snaps = await db.getAll(...refs);
      for (const snap of snaps) {
        this.userData.set(
          snap.id,
          snap.exists ? (snap.data() as Record<string, unknown>) : null,
        );
        this.metrics.userDocReads += 1;
      }
    }
  }

  resolveTokensForUserIds(
    userIds: string[],
    pushType: string,
  ): ResolvedAudience {
    const tokens: string[] = [];
    const resolved: string[] = [];

    for (const uid of userIds) {
      if (!uid) continue;
      const data = this.userData.get(uid);
      if (data === undefined) continue;
      if (data === null) continue;

      const prefs = data.notificationPrefs as Record<string, unknown> | undefined;
      if (!userAllowsPushType(prefs, pushType)) continue;

      resolved.push(uid);
      tokens.push(...extractFcmTokens(data));
    }

    this.metrics.usersResolved = resolved.length;
    this.metrics.tokensCollected = tokens.length;

    return {
      userIds: resolved,
      tokens: [...new Set(tokens)],
    };
  }
}
