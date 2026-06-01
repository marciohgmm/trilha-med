# RBAC — Controle de acesso (Trilha Med)

Documentação da implementação concluída sobre a arquitetura da etapa anterior.

---

## 1. Visão geral

O RBAC reutiliza e estende os componentes em `lib/core/permissions/` e expõe o módulo via `lib/core/rbac/rbac.dart`.

| Camada | Responsabilidade |
|--------|------------------|
| **Permissions** | `AppRole`, `AppPermission`, `PermissionContext`, `PermissionChecker` |
| **RBAC Catalog** | Snapshot roles + permission keys (Firestore ou fallback) |
| **RbacRepository** | Persistência `platform_rbac_roles` / `platform_rbac_permissions` |
| **RbacService** | Resolver contexto, admin panel, auditoria, assign roles |
| **UI Guards** | `AdminGate`, `RbacGate`, `RbacGuard` |

**Não altera:** login, telas de aluno, fluxos de estudo.

**Unificação admin (R1 + F4):** resolução única em `AdminAccessService`; `AdminAuthService.resolveAccess` delega para ele. Detalhes: `docs/ADMIN_UNIFICATION.md`.

---

## 2. Perfis (5 principais)

| Perfil | Chave | Seed Firestore |
|--------|-------|----------------|
| Administrador Master | `masterAdmin` | Todas as permissões |
| Administrador | `admin` | Painel + conteúdo + comercial + usuários |
| Suporte | `support` | Painel + usuários + auditoria leitura |
| Vendedor | `seller` | Conteúdo leitura + dashboard |
| Usuário | `user` | `content.read` |

Alias legado: `student` → `user`.

**Founder** (`marciohgmm@gmail.com`): tratado como `masterAdmin` + todas as permissões do catálogo.

**Admin legado** (`admins/{uid}`, `users.isAdmin`): mapeado para papel `admin` se não houver `rbacRoles` (`AdminLegacyCompat.ensureRbacRolesPersisted`).

---

## 3. Firestore

### Coleções

| Coleção | Documento | Campos principais |
|---------|-----------|-------------------|
| `platform_rbac_permissions` | ID = chave (ex. `content.read`) | `label`, `description`, `isActive`, `category` |
| `platform_rbac_roles` | ID = chave do papel | `label`, `permissionKeys[]`, `isSystem`, `priority` |

### Usuário (`users/{uid}`)

**Privacidade (S1):** leitura do documento raiz apenas para o dono ou `isAppAdmin()`. Campos públicos em `users/{uid}/public_profile/profile` — ver `docs/USERS_PRIVACY_S1.md`.

| Campo | Uso |
|-------|-----|
| `rbacRoles` | Lista de chaves de papel (preferencial) |
| `roles` | Alias legado (platform extension) |
| `extraPermissions` | Permissões avulsas (strings) |
| `isAdmin` | Legado — reforça papel admin no RBAC |

### Seed automático

Na primeira carga do catálogo, `FirestoreRbacRepository.ensureDefaultSeed()` grava permissões e papéis se `platform_rbac_roles` estiver vazio.

### Nova permissão sem deploy de app

1. Crie documento em `platform_rbac_permissions/{nova.chave}`.
2. Adicione `nova.chave` em `permissionKeys` do papel desejado em `platform_rbac_roles/{papel}`.
3. Use `ctx.hasKey('nova.chave')` ou `RbacGuard.check(permissionKey: 'nova.chave')`.

---

## 4. Permissões no código (`AppPermission`)

Chaves estáveis usadas no seed e no fallback offline:

- `admin.panel.access` — entrar no painel admin
- `rbac.manage` — editar papéis de usuários
- `content.read` / `content.write`
- `subscription.manage`, `payment.view`, `payment.refund`
- `coupon.manage`, `seller.manage`, `affiliate.manage`, …
- `audit.read`, `dashboard.view`, `notification.broadcast`

Lista completa: `AppPermission.allKeys`.

---

## 5. API principal

### `RbacService.instance`

```dart
final rbac = RbacService.instance;
// ou PlatformRegistry.instance.rbac

final ctx = await rbac.resolveContext();
if (ctx.canAccessAdminPanel) { ... }
if (ctx.hasKey('content.write')) { ... }
if (ctx.has(AppPermission.couponManage)) { ... }
```

### Auditoria (`PlatformAuditService`)

| Evento | Quando |
|--------|--------|
| `access.granted` | `AdminGate` / `RbacGate` liberam |
| `access.denied` | Acesso bloqueado |
| `permission.changed` | `assignRolesToUser` |

Coleção: `platform_audit_logs`.

---

## 6. Guards de UI

### `AdminGate` (existente, estendido)

- Continua usando `AdminAuthService.resolveAccess`.
- **OU** `RbacService.canAccessAdminPanel`.
- Registra auditoria em toda tentativa.

### `RbacGate` (novo)

Envolve sub-rotas admin com permissão específica:

```dart
RbacGate(
  routeName: 'admin.osce_cases',
  requiredPermission: AppPermission.contentWrite,
  child: AdminOsceCasesListPage(),
)
```

### `RbacGuard` (novo)

```dart
await RbacGuard.pushIfAllowed(
  context: context,
  routeName: 'admin.coupons',
  permissionKey: 'coupon.manage',
  page: const CouponsAdminPage(),
);
```

---

## 7. Atribuir papéis a um usuário

```dart
await RbacService.instance.assignRolesToUser(
  targetUserId: uid,
  roles: [AppRole.support],
  actor: await RbacService.instance.resolveContext(),
);
```

Requer `rbac.manage` ou founder.

---

## 8. Regras de segurança

- Leitura de catálogo RBAC: usuário autenticado.
- Escrita em papéis/permissões: `isAppAdmin()`.
- Deploy: `firebase deploy --only firestore:rules`

---

## 9. Arquivos da implementação

| Criados | Modificados |
|---------|-------------|
| `lib/core/rbac/*` | `lib/core/permissions/*` |
| `lib/application/rbac/rbac_service.dart` | `lib/widgets/admin/admin_gate.dart` |
| `lib/widgets/admin/rbac_gate.dart` | `lib/application/platform/platform_registry.dart` |
| `lib/widgets/admin/rbac_guard.dart` | `firestore.rules` |
| `lib/domain/platform/models/rbac_*.dart` | `lib/core/audit/audit_event_type.dart` |
| `lib/infrastructure/.../firestore_rbac_repository.dart` | |
| `lib/data/rbac_default_seed.dart` | |

Relatório pré-implementação: `docs/RBAC_IMPLEMENTATION_REPORT.md`.

---

## 10. Compatibilidade

| Cenário | Comportamento |
|---------|----------------|
| Founder | Acesso total (como antes) |
| `admins/{uid}` | Acesso admin (como antes) + seed RBAC |
| `users.isAdmin` | Acesso admin via RBAC |
| Aluno comum | Papel `user`, sem painel admin |
| Offline / erro Firestore | `RbacCatalog.fallback()` com matrix estática |

---

## 11. Próximos passos sugeridos

1. Tela admin para CRUD de `platform_rbac_roles` / permissions.
2. Envolver cada botão do `AdminPage` com `RbacGuard` + permissionKey.
3. Cloud Function para validar pagamento antes de atribuir `admin` ou `seller`.
4. Sincronizar `rbacRoles` ao promover admin em `AdminAuthService` (opcional, fase separada).
