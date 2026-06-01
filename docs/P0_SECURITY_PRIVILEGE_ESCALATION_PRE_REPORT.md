# Pré-relatório — P0-A Escalada de privilégios (`isAdmin` / `rbacRoles`)

**Data:** 2026-05-19  
**Modo:** Auditoria somente leitura (pré-correção)  
**Referência:** `docs/LGPD_SECURITY_AUDIT.md` (S-P0-01)

---

## 1. Escopo mapeado

| Componente | Caminho | Papel |
|------------|---------|--------|
| Firestore Rules | `firestore.rules` | Autorização definitiva |
| Storage Rules | `storage.rules` | Usa `users.isAdmin` via `isAppAdmin()` — **não** grava privilégios |
| AdminAuthService | `lib/services/auth/admin_auth_service.dart` | `grantAdmin` / `revokeAdmin` / `syncCurrentUser` |
| AdminLegacyCompat | `lib/application/admin/admin_legacy_compat.dart` | Persiste `rbacRoles` implícitos |
| RbacService | `lib/application/rbac/rbac_service.dart` | `assignRolesToUser` (UI + checagem cliente) |
| PermissionChecker | `lib/core/permissions/permission_checker.dart` | Lê `isAdmin` / `rbacRoles` |
| AdminGate | `lib/widgets/admin/admin_gate.dart` | Bloqueio UI (não segurança) |
| Painel Mestre | `master_admin_*`, `grantAdmin` | Concessão legítima se actor for admin |
| Cloud Functions | `functions/src/push/adminAuth.ts` | Lê `isAdmin` — não concede via cliente |
| Coleções | `users/{uid}`, `admins/{uid}` | Alvo da escalada |
| RBAC catálogo | `platform_rbac_roles`, `platform_rbac_permissions` | Write já `isAppAdmin()` |
| Entitlements | `users/{uid}/platform_entitlements` | Write já `isAppAdmin()` |

---

## 2. Respostas obrigatórias

### 1. Um usuário autenticado consegue alterar o próprio `users/{uid}`?

**Sim.** Regra atual:

```148:151:firestore.rules
      allow update: if isOwner(userId)
        || isAppAdmin()
        || (isSignedIn() && isOscePerformanceOnlyUpdate())
        || isLiveEventRewardGrantToUser(userId);
```

Qualquer dono pode atualizar o documento raiz **sem restrição de campos**.

### 2. Consegue criar/modificar `isAdmin`?

**Sim (crítico).** Não há `hasOnly` nem comparação de valor. Um cliente Firestore pode:

```javascript
firebase.firestore().collection('users').doc(uid).update({ isAdmin: true });
```

`isAppAdmin()` nas rules passa a retornar `true` para esse usuário (L29–34).

### 3. Consegue criar/modificar `rbacRoles`?

**Sim (crítico).** Mesmo vetor. Exemplo:

```javascript
.update({ rbacRoles: ['master_admin', 'admin'] });
```

`RbacService` / `PermissionChecker` no app passam a conceder permissões de Painel Mestre **sem** passar por `grantAdmin`.

### 4. Consegue criar `admins/{uid}`?

**Não** (para usuário comum). Hoje:

```136:138:firestore.rules
    match /admins/{adminId} {
      allow read: if isSignedIn() && (request.auth.uid == adminId || isAdmin());
      allow create, update, delete: if isFounder();
```

Apenas **founder** (e-mail fixo) cria docs em `admins/`. Usuário comum: **negado**.

**Porém:** não precisa de `admins/` se escalou via `users.isAdmin` ou `rbacRoles`.

### 5. Existe caminho indireto por Cloud Function?

| Function | Escalada? |
|----------|-----------|
| `registerFcmToken` | Não — merge em `fcmTokens` |
| `createMercadoPagoCheckout` | Não |
| `reconcileMyMercadoPagoPayments` | Não |
| Push admin callables | `assertAppAdmin` no servidor |
| `grantAdmin` (cliente) | Escreve `isAdmin` — **legítimo** se actor já for admin; inválido se rules permitirem auto-`isAdmin` antes |

Nenhuma Function concede admin automaticamente a usuários comuns.

### 6. Existe caminho indireto por Painel Mestre?

**Sim, legítimo:** `AdminAuthService.grantAdmin` e `RbacService.assignRolesToUser` escrevem `isAdmin` / `rbacRoles` **como admin autenticado**. Depende de `AdminAccessService` no cliente — **não** substitui rules.

**Risco:** atacante não precisa do Painel se usar SDK direto (item 2–3).

### 7. Existe risco de privilege escalation?

**Sim — P0 confirmado.** Vetor principal: **autoatribuição** `isAdmin` / `rbacRoles` em `users/{ownUid}`.

---

## 3. Escritas legítimas de campos sensíveis (cliente)

| Origem | Campos | Condição |
|--------|--------|----------|
| `AdminAuthService.syncCurrentUser` | `isAdmin` | Founder ou listado em `admins/` |
| `AdminAuthService.grantAdmin` | `isAdmin: true` | Actor admin |
| `AdminAuthService.revokeAdmin` | `isAdmin: false` | Actor admin |
| `AdminLegacyCompat.ensureRbacRolesPersisted` | `rbacRoles` | Admin/founder implícito (não grava só `user`) |
| `AdminLegacyCompat.syncRbacAfterGrant/Revoke` | `rbacRoles` | Após grant/revoke admin |
| `RbacService.assignRolesToUser` | `rbacRoles` | Checagem `rbac.manage` no cliente |

Correção nas rules deve **preservar** esses fluxos apenas via `isAppAdmin()`.

---

## 4. Campos de perfil usados pelo app (dono)

| Campo | Uso |
|-------|-----|
| `nome`, `telefone`, `cidade`, `email`, `atualizadoEm` | `PerfilPage` |
| `email`, `updatedAt` | `UserProfileService` |
| `notificationPrefs` | Push prefs |
| `lastActiveAt`, `signupTrackedAt`, `createdAt` | Analytics |
| `ultimaMensagemVisualizada` | `GlobalMessageService` |
| `ultimoAcesso`, `ultimaMateria`, … | Progresso flashcards |
| `xp`, `badges`, `_liveEventRewardEventId` | Live Events (regra D2) |
| `oscePerformance` | OSCE (regra dedicada) |

---

## 5. Storage rules

`storage.rules` **não** permite escrita em Firestore; apenas lê `users.isAdmin` para `isAppAdmin()`. Escalada via Storage: **não aplicável**.

---

## 6. Conclusão pré-correção

| Pergunta | Resposta |
|----------|----------|
| Escalada via `users`? | **Sim** |
| Escalada via `admins/`? | **Não** (só founder) |
| UI Painel necessária para ataque? | **Não** |
| Severidade | **P0** |

**Correção planejada:** rules com bloqueio de campos privilegiados para dono; `admins/*` CRUD somente `isAppAdmin()`; manter exceções OSCE / Live Events.

---

*Documento gerado na Etapa 1 — base para `docs/P0_SECURITY_FIXES_REPORT.md`.*
