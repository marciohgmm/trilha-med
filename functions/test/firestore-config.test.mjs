import assert from "node:assert";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "../..");

function loadIndexes() {
  return JSON.parse(readFileSync(join(root, "firestore.indexes.json"), "utf8"));
}

function loadRules() {
  return readFileSync(join(root, "firestore.rules"), "utf8");
}

test("firestore.indexes.json — estrutura válida", () => {
  const data = loadIndexes();
  assert.ok(Array.isArray(data.indexes), "indexes deve ser array");
  for (const idx of data.indexes) {
    assert.ok(idx.collectionGroup, "collectionGroup obrigatório");
    assert.ok(Array.isArray(idx.fields) && idx.fields.length > 0, "fields obrigatório");
    for (const field of idx.fields) {
      assert.ok(field.fieldPath, "fieldPath obrigatório");
      const hasOrder = field.order === "ASCENDING" || field.order === "DESCENDING";
      const hasArray = field.arrayConfig === "CONTAINS";
      assert.ok(hasOrder || hasArray, `campo inválido em ${idx.collectionGroup}`);
    }
  }
});

test("firestore.indexes.json — sem índices compostos duplicados", () => {
  const data = loadIndexes();
  const keys = new Set();
  for (const idx of data.indexes) {
    const fieldKey = idx.fields
      .map((f) => `${f.fieldPath}:${f.order ?? f.arrayConfig ?? ""}`)
      .join("|");
    const key = `${idx.collectionGroup}::${idx.queryScope ?? "COLLECTION"}::${fieldKey}`;
    assert.ok(!keys.has(key), `Índice duplicado: ${key}`);
    keys.add(key);
  }
});

test("firestore.rules — estrutura mínima", () => {
  const rules = loadRules();
  assert.match(rules, /rules_version\s*=\s*'2'/);
  assert.match(rules, /service\s+cloud\.firestore/);
  assert.match(rules, /match\s+\/databases\/\{database\}\/documents/);
});

test("firestore.rules — chaves balanceadas", () => {
  const rules = loadRules();
  const open = (rules.match(/{/g) ?? []).length;
  const close = (rules.match(/}/g) ?? []).length;
  assert.equal(open, close, "chaves { } desbalanceadas em firestore.rules");
});

test("firestore.rules — P0-3 proteção de conteúdo", () => {
  const rules = loadRules();
  assert.match(rules, /isFlashcardsScopedStudentList/);
  assert.match(rules, /isQuestoesScopedStudentList/);
  assert.match(rules, /questoes_materia_stats/);
  assert.match(rules, /allow list: if isSignedIn\(\)/);
});

test("firestore.rules — P1-6 analytics daily", () => {
  const rules = loadRules();
  assert.match(rules, /platform_analytics_daily/);
  assert.match(rules, /active_users/);
  assert.match(rules, /expireAt/);
});

test("firestore.rules — platform_rate_limits somente backend", () => {
  const rules = loadRules();
  assert.match(rules, /platform_rate_limits/);
  assert.match(rules, /allow read, write: if false/);
});

test("firestore.rules — platform_feature_flags", () => {
  const rules = loadRules();
  assert.match(rules, /platform_feature_flags/);
  assert.match(rules, /allow read: if isSignedIn\(\)/);
  assert.match(rules, /allow create, update: if isAppAdmin\(\)/);
});
