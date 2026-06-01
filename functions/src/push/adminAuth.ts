import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../constants";

const FOUNDER_EMAIL = "marciohgmm@gmail.com";

export async function assertAppAdmin(
  uid: string,
  email?: string | null,
): Promise<void> {
  if (email?.toLowerCase() === FOUNDER_EMAIL) return;

  const db = admin.firestore();
  const adminDoc = await db.collection("admins").doc(uid).get();
  if (adminDoc.exists) return;

  const userDoc = await db.collection(COLLECTIONS.users).doc(uid).get();
  if (userDoc.data()?.isAdmin === true) return;

  throw new HttpsError("permission-denied", "Acesso administrativo necessário.");
}
