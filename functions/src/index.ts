import * as admin from "firebase-admin";
import { createMercadoPagoCheckout } from "./createCheckout";
import { mercadopagoWebhook, expireSubscriptionsScheduled } from "./webhook";
import {
  reconcileMercadoPagoPaymentsScheduled,
  reconcileMyMercadoPagoPayments,
} from "./subscription/paymentReconciliation";
import { deleteMyAccount } from "./accountDeletion";
import {
  purgeAnalyticsEventsScheduled,
  syncAnalyticsDauScheduled,
} from "./analyticsScheduled";
import {
  registerFcmToken,
  createPushCampaign,
  onPushCampaignCreated,
  notifyLiveEventBroadcast,
  notifyLiveEventUser,
  scheduleLiveEventReminders,
} from "./push/callables";
import {
  rateLimitBeforeCreate,
  rateLimitBeforeSignIn,
} from "./rateLimit/authBlocking";
import { rateLimitPasswordReset } from "./rateLimit/authPasswordResetCallable";
import {
  pushFlashcardReviewScheduled,
  pushCronogramaOverdueScheduled,
  pushSimuladoAvailableScheduled,
  pushSubscriptionRenewalScheduled,
  pushLiveEventsScheduled,
} from "./push/scheduled";

admin.initializeApp();

export {
  rateLimitBeforeSignIn,
  rateLimitBeforeCreate,
  rateLimitPasswordReset,
  createMercadoPagoCheckout,
  mercadopagoWebhook,
  expireSubscriptionsScheduled,
  reconcileMercadoPagoPaymentsScheduled,
  reconcileMyMercadoPagoPayments,
  deleteMyAccount,
  purgeAnalyticsEventsScheduled,
  syncAnalyticsDauScheduled,
  registerFcmToken,
  createPushCampaign,
  onPushCampaignCreated,
  notifyLiveEventBroadcast,
  notifyLiveEventUser,
  scheduleLiveEventReminders,
  pushFlashcardReviewScheduled,
  pushCronogramaOverdueScheduled,
  pushSimuladoAvailableScheduled,
  pushSubscriptionRenewalScheduled,
  pushLiveEventsScheduled,
};
