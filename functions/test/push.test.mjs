import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import assert from "node:assert/strict";
import { extractFcmTokens, userAllowsPushType } from "../lib/push/fcmSend.js";
import { LIVE_EVENT_PUSH_AUDIENCE, PUSH_SEGMENTS } from "../lib/push/constants.js";
import { liveEventPushSegmentFromEvent } from "../lib/push/segmentation.js";

const callablesSrc = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), "../src/push/callables.ts"),
  "utf8",
);

test("extractFcmTokens reads keys from user document", () => {
  assert.deepEqual(
    extractFcmTokens({ fcmTokens: { abc: {}, def: {} } }),
    ["abc", "def"],
  );
  assert.deepEqual(extractFcmTokens({}), []);
});

test("userAllowsPushType default true when prefs missing", () => {
  assert.equal(userAllowsPushType(undefined, "flashcard_review"), true);
});

test("userAllowsPushType respects explicit false", () => {
  assert.equal(
    userAllowsPushType({ promotional: false }, "promotional"),
    false,
  );
  assert.equal(
    userAllowsPushType({ promotional: false }, "admin_broadcast"),
    true,
  );
});

test("liveEventPushSegmentFromEvent defaults to participants", () => {
  assert.equal(
    liveEventPushSegmentFromEvent(undefined),
    PUSH_SEGMENTS.liveEventAudience,
  );
  assert.equal(
    liveEventPushSegmentFromEvent(""),
    PUSH_SEGMENTS.liveEventAudience,
  );
  assert.equal(
    liveEventPushSegmentFromEvent(LIVE_EVENT_PUSH_AUDIENCE.participants),
    PUSH_SEGMENTS.liveEventAudience,
  );
});

test("liveEventPushSegmentFromEvent platform_public uses active_7d not all", () => {
  const segment = liveEventPushSegmentFromEvent(
    LIVE_EVENT_PUSH_AUDIENCE.platformPublic,
  );
  assert.equal(segment, PUSH_SEGMENTS.active7d);
  assert.notEqual(segment, PUSH_SEGMENTS.all);
});

test("notifyLiveEventUser exige host/admin e validação de eliminated", () => {
  assert.match(callablesSrc, /export const notifyLiveEventUser/);
  assert.match(callablesSrc, /assertAppAdmin/);
  assert.match(callablesSrc, /assertLiveEventParticipantEliminated/);
  assert.match(callablesSrc, /unauthenticated/);
});

test("scheduleLiveEventReminders exige auth e host/admin", () => {
  assert.match(callablesSrc, /export const scheduleLiveEventReminders/);
  assert.match(callablesSrc, /assertLiveEventHostOrAdmin/);
  assert.match(callablesSrc, /Login necessário/);
});
