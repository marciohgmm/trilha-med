# Unificação administrativa (R1 + F4)

**Status:** Implementado  
**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `RBAC.md`, `RBAC_IMPLEMENTATION_REPORT.md`, `ADMIN_UNIFICATION_PRE_REPORT.md`

---

## Objetivo

RBAC é a **fonte principal** de permissões administrativas. Sinais legados (founder, `admins/{uid}`, `users.isAdmin`) permanecem ativos e são mapeados para papéis RBAC equivalentes via camada de compatibilidade — **sem remoção** dos mecanismos antigos.

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│  UI: HomePage, AdminGate, AdminPage, MasterAdminShell       │
└───────────────────────────┬─────────────────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   AdminAccessService       │  ← resolução única (R1)
              │   resolveAdminAccess()     │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   RbacService              │
              │   resolveContext()         │  ← RBAC + catálogo
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   AdminLegacyCompat        │  ← Fase 1: mapeamento
              │   ensureRbacRolesPersisted │
              └─────────────┬─────────────┘
                            │
     founder email │ admins/{uid} │ users.isAdmin │ users.rbacRoles
```

### Ciclo de dependência (evitado)

- `RbacService.resolveContext` **não** chama `AdminAuthService.resolveAccess`.
- Lê sinais legados diretamente (`AdminLegacyCompat` + documento `users`).
- `AdminAuthService.resolveAccess` delega a `AdminAccessService.resolveAdminAccess`.

---

## Fase 1 — Mapeamento legado → RBAC

| Sinal | Papel RBAC implícito | Condição |
|-------|----------------------|----------|
| Founder (`marciohgmm@gmail.com`) | `masterAdmin` | `rbacRoles` vazio |
| `admins/{uid}` existe | `admin` | `rbacRoles` vazio |
| `users.isAdmin == true` | `admin` | `rbacRoles` vazio |
| `rbacRoles` já preenchido | Respeitar Firestore | Nunca sobrescrever |

Implementação: `lib/application/admin/admin_legacy_compat.dart`

- `implicitRoles()` — cálculo em memória  
- `ensureRbacRolesPersisted()` — grava `rbacRoles` uma vez (merge)  
- `syncRbacAfterGrant()` / `syncRbacAfterRevoke()` — após grant/revoke legado  

---

## Fase 2 — Serviço único

`lib/application/admin/admin_access_service.dart`

| Método | Uso |
|--------|-----|
| `resolveAdminAccess()` | Home, AdminGate, delegação de `AdminAuthService` |
| `canAccessAdminPanel()` | Atalho booleano |
| `resolvePermissionContext()` | Painel Mestre, `RbacGuard` |
| `logAdminAccessGranted()` / `logAdminAccessRevoked()` | Auditoria Fase 4 |

Retorno: `AdminAccessResult` (`allowed`, `isFounder`, `listedInAdmins`, `hasIsAdminFlag`, `permissionContext`).

Critério `allowed`: `PermissionContext.canAccessAdminPanel` (founder, legado agregado, papéis `admin`/`masterAdmin`, ou permissão `admin.panel.access`).

---

## Fase 3 — Consumidores alinhados

| Componente | Antes | Depois |
|------------|-------|--------|
| `HomePage` (gesto oculto + teste) | `resolveAccess` (só founder + admins) | `AdminAccessService.resolveAdminAccess` |
| `AdminGate` | `legacy \|\| rbac` | só `AdminAccessService` (+ bypass founder opcional) |
| `AdminAuthService.resolveAccess` | lógica própria | delega a `AdminAccessService` |
| `RbacService.resolveContext` | chamava `resolveAccess` | legado completo + `ensureRbacRolesPersisted` |
| Painel Mestre | `RbacService.resolveContext` | inalterado — já usa contexto RBAC unificado |

`AdminAuthService` mantém: `grantAdmin`, `revokeAdmin`, `syncCurrentUser`, `watchIsAdmin`, coleção `admins`.

---

## Fase 4 — Auditoria

| Evento | `metadata.action` | Origem |
|--------|-------------------|--------|
| Concessão admin legado | `admin.access.granted` | `AdminAuthService.grantAdmin` |
| Revogação admin legado | `admin.access.revoked` | `AdminAuthService.revokeAdmin` |
| Atribuição papéis RBAC | `rbac.roles.assigned` | `RbacService.assignRolesToUser` |
| Tentativa de rota admin | `admin.access.attempt` | `RbacService.logAccessAttempt` (AdminGate) |

Coleção de auditoria: via `PlatformRegistry.instance.audit` (`AuditEventType.permissionChanged`).

---

## Compatibilidade preservada

| Requisito | Como |
|-----------|------|
| Admins atuais em `admins/` | `listedInAdmins` + papel `admin` implícito |
| Founder | `isFounder` + `masterAdmin` + bypass AdminGate |
| `users.isAdmin` | Incluído em `isLegacyAdmin` e mapeamento |
| AdminGate | Mesma UX; uma única verificação |
| Painel Mestre | `RbacGuard` + `resolveContext` |
| Login / auth | Sem alteração |

---

## Plano futuro — remoção segura dos legados

**Não executar até:** métricas de migração, regras Firestore alinhadas, e ausência de contas só com `isAdmin` sem `rbacRoles`.

### Etapa A — Observabilidade (1–2 sprints)

1. Log estruturado: % usuários com `rbacRoles` preenchido vs só legado.  
2. Dashboard admin: listar contas com `isAdmin` sem `admins/{uid}` (inconsistências).  
3. Alertar grant/revoke sem evento de auditoria.

### Etapa B — Consolidação de dados

1. Script/admin job: backfill `rbacRoles` para todos com sinal legado (idempotente).  
2. Garantir `admins/{uid}` para cada `isAdmin == true` (ou revogar flag órfã).  
3. Documentar founder apenas em RBAC (`masterAdmin`), manter e-mail como fallback de emergência.

### Etapa C — Deprecar leitura legada no app

1. `resolveContext`: parar de usar `isLegacyAdmin` agregado; confiar só em `rbacRoles` + founder.  
2. `AdminAccessService`: remover ramos `listedInAdmins` / `isAdmin` da resolução.  
3. `watchIsAdmin` na Home → stream de `rbacRoles` ou `PermissionContext`.

### Etapa D — Firestore e regras

1. Regras: `isAdmin()` baseado em custom claims ou `rbacRoles` (não `users.isAdmin`).  
2. Remover escrita em `isAdmin` no `grantAdmin`/`revokeAdmin`.  
3. Arquivar coleção `admins` (read-only) após migração.

### Etapa E — Remoção de código

1. Remover `AdminLegacyCompat` (ou reduzir a no-op).  
2. Remover `founderEmail` hardcoded → config remota / custom claim.  
3. Atualizar `TECHNICAL_AUDIT.md` e fechar itens R1/F4.

**Rollback:** manter flags de feature `useLegacyAdminSignals` (não implementado ainda) até Etapa C.

---

## Checklist de testes

### Founder

- [ ] Login com `marciohgmm@gmail.com` abre admin pelo gesto 4s na Home  
- [ ] `AdminGate` libera `AdminPage` imediatamente (bypass)  
- [ ] Painel Mestre visível com permissão `dashboard.view`  
- [ ] `syncCurrentUser` mantém `admins/{uid}` e `isAdmin: true`

### Admin em `admins/{uid}`

- [ ] Gesto oculto abre painel  
- [ ] `AdminGate` libera rotas filhas  
- [ ] Primeiro login grava `rbacRoles: ['admin']` se vazio (merge)  
- [ ] Segundo login **não** altera `rbacRoles` se já customizado

### Somente `users.isAdmin == true` (sem doc em `admins`)

- [ ] Gesto oculto abre painel (regressão R2)  
- [ ] `resolveAdminAccess().allowed == true`  
- [ ] Backfill `rbacRoles` na primeira resolução

### Usuário comum

- [ ] Gesto oculto mostra SnackBar de acesso restrito  
- [ ] `AdminGate` exibe tela de bloqueio  
- [ ] Fluxos de flashcards/questões inalterados

### Grant / Revoke (admin logado)

- [ ] `grantAdmin` cria `admins/{uid}`, `isAdmin: true`, adiciona `admin` em `rbacRoles`  
- [ ] Auditoria `admin.access.granted` em `platform_audit` (ou coleção configurada)  
- [ ] `revokeAdmin` remove `admins`, `isAdmin: false`, ajusta `rbacRoles`  
- [ ] Auditoria `admin.access.revoked`  
- [ ] Revogar founder **falha** com mensagem clara

### RBAC explícito

- [ ] Usuário só com `rbacRoles: ['support']` acessa painel se papel tiver `admin.panel.access`  
- [ ] `assignRolesToUser` gera auditoria `rbac.roles.assigned`  
- [ ] Papéis explícitos **não** são sobrescritos por `ensureRbacRolesPersisted`

### Painel Mestre

- [ ] Entrada em `AdminPage` → “Painel Mestre” respeita `RbacGuard`  
- [ ] Módulos filtrados por permissões do contexto  
- [ ] Sem regressão em telas admin legadas (OSCE, live events, etc.)

### Regressão auth

- [ ] Login e-mail/senha normal  
- [ ] Logout na Home  
- [ ] Biometria (se habilitada) inalterada  

### Live Events (coordenador)

- [ ] Host e admin ainda passam em `LiveEventService.canActAsEventCoordinator` (usa `resolveAccess` → unificado)

---

## Arquivos

| Arquivo | Função |
|---------|--------|
| `lib/application/admin/admin_legacy_compat.dart` | Mapeamento Fase 1 |
| `lib/application/admin/admin_access_service.dart` | Resolução única Fase 2–4 |
| `lib/application/rbac/rbac_service.dart` | Contexto RBAC sem ciclo |
| `lib/services/auth/admin_auth_service.dart` | Legado + delegação + grant/revoke |
| `lib/widgets/admin/admin_gate.dart` | Guard unificado |
| `lib/screens/home_page.dart` | Gesto oculto unificado |
| `lib/core/permissions/permission_context.dart` | `hasIsAdminDocumentFlag` |

---

## Critérios de sucesso (R1 + F4)

1. Uma única lógica de `allowed` para Home, AdminGate e `resolveAccess`.  
2. `users.isAdmin` considerado na resolução RBAC.  
3. Backfill não destrutivo de `rbacRoles`.  
4. Auditoria em grant/revoke admin.  
5. Legado (`admins`, `isAdmin`, founder) **ainda presente** no código e Firestore.
