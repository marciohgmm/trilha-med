import assert from "node:assert/strict";
import test from "node:test";
import { nextWindowState } from "../lib/rateLimit/rateLimitCore.js";

const HOUR = 60 * 60 * 1000;

test("A) abaixo do limite — permitido", () => {
  const r1 = nextWindowState(1000, null, 0, HOUR, 3);
  assert.equal(r1.allowed, true);
  assert.equal(r1.count, 1);

  const r2 = nextWindowState(2000, r1.windowStartMs, r1.count, HOUR, 3);
  assert.equal(r2.allowed, true);
  assert.equal(r2.count, 2);

  const r3 = nextWindowState(3000, r2.windowStartMs, r2.count, HOUR, 3);
  assert.equal(r3.allowed, true);
  assert.equal(r3.count, 3);
});

test("B) acima do limite — bloqueado", () => {
  const r1 = nextWindowState(1000, null, 0, HOUR, 3);
  const r2 = nextWindowState(2000, r1.windowStartMs, r1.count, HOUR, 3);
  const r3 = nextWindowState(3000, r2.windowStartMs, r2.count, HOUR, 3);
  const r4 = nextWindowState(4000, r3.windowStartMs, r3.count, HOUR, 3);
  assert.equal(r4.allowed, false);
  assert.equal(r4.count, 4);
});

test("janela expirada reinicia contador", () => {
  const r1 = nextWindowState(1000, null, 0, HOUR, 2);
  const r2 = nextWindowState(2000, r1.windowStartMs, r1.count, HOUR, 2);
  assert.equal(r2.allowed, true);
  assert.equal(r2.count, 2);

  const afterWindow = nextWindowState(1000 + HOUR + 1, r2.windowStartMs, r2.count, HOUR, 2);
  assert.equal(afterWindow.allowed, true);
  assert.equal(afterWindow.count, 1);
});

test("delete account — 2 por dia", () => {
  const DAY = 24 * HOUR;
  const a = nextWindowState(0, null, 0, DAY, 2);
  const b = nextWindowState(1, a.windowStartMs, a.count, DAY, 2);
  assert.equal(b.allowed, true);
  const c = nextWindowState(2, b.windowStartMs, b.count, DAY, 2);
  assert.equal(c.allowed, false);
});
