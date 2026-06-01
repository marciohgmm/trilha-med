import assert from "node:assert";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "../..");
const rules = readFileSync(join(root, "firestore.rules"), "utf8");

test("A) rules bloqueiam campos privilegiados no update do dono", () => {
  assert.match(rules, /function isOwnerSafeProfileUpdate/);
  assert.match(rules, /userPrivilegedFieldKeys/);
  assert.match(rules, /hasAny\(userPrivilegedFieldKeys\(\)\)/);
  assert.match(rules, /'isAdmin'/);
  assert.match(rules, /'rbacRoles'/);
});

test("A) rules bloqueiam isAdmin/rbacRoles no create do dono", () => {
  assert.match(rules, /function ownerSafeUserCreate/);
  assert.match(rules, /ownerSafeUserCreate\(\)/);
});

test("B) admins/{uid} CUD somente isAppAdmin", () => {
  const adminsBlock = rules.match(
    /match \/admins\/\{adminId\}[\s\S]*?match \/users/
  )?.[0];
  assert.ok(adminsBlock, "bloco admins deve existir");
  assert.match(adminsBlock, /allow create, update, delete: if isAppAdmin\(\)/);
  assert.doesNotMatch(
    adminsBlock,
    /allow create, update, delete: if isFounder\(\)/
  );
});

test("users update não permite isOwner sem isOwnerSafeProfileUpdate", () => {
  const usersBlock = rules.match(
    /match \/users\/\{userId\}[\s\S]*?match \/public_profile/
  )?.[0];
  assert.ok(usersBlock);
  assert.match(usersBlock, /allow update: if isAppAdmin\(\)/);
  assert.match(usersBlock, /isOwnerSafeProfileUpdate\(\)/);
  assert.doesNotMatch(
    usersBlock,
    /allow update: if isOwner\(userId\)\s*\|\|\s*isAppAdmin/
  );
});

test("platform_entitlements write restrito a admin", () => {
  assert.match(
    rules,
    /match \/users\/\{userId\}\/platform_entitlements[\s\S]*?allow write: if isAppAdmin\(\)/
  );
});

test("platform_rbac write restrito a admin", () => {
  assert.match(
    rules,
    /match \/platform_rbac_roles[\s\S]*?allow create, update, delete: if isAppAdmin\(\)/
  );
});

test("simulação: tentativa isAdmin deve falhar (documentação rules)", () => {
  assert.match(rules, /userPrivilegedFieldsUnchanged/);
  assert.match(rules, /ownerAllowedUserRootUpdateKeys/);
});
