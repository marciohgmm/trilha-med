# Relatório pré-implementação — RBAC

**Data:** 2026-05-19

## O que já existe (reutilizar)

| Componente | Local | Ação |
|------------|-------|------|
| `AppRole` | `lib/core/permissions/app_role.dart` | **Estender** (masterAdmin, labels PT) |
| `AppPermission` | `lib/core/permissions/app_permission.dart` | **Estender** (admin.panel.access) |
| `PermissionContext` | `lib/core/permissions/permission_context.dart` | **Estender** (chaves dinâmicas) |
| `PermissionChecker` | `lib/core/permissions/permission_checker.dart` | **Estender** (catálogo Firestore) |
| `RolePermissionMatrix` | `app_permission.dart` | **Manter** como fallback offline |
| `PlatformAuditService` | `lib/application/platform/` | **Reutilizar** para logs |
| `PlatformRegistry` | `lib/application/platform/` | **Estender** (expor RBAC) |
| `AdminGate` | `lib/widgets/admin/admin_gate.dart` | **Estender** (RBAC + auditoria) |
| `AdminAuthService` | `lib/services/auth/` | **Não modificar** |
| `AuditLogEntry` / `AuditEventType` | `lib/core/audit/` | **Estender** eventos de acesso |

**Nota:** Não existe `lib/core/rbac/` — será criado como **barrel** reexportando `permissions/` + novos tipos.

## Perfis solicitados → `AppRole`

| Perfil | Chave Firestore |
|--------|-----------------|
| Administrador Master | `masterAdmin` |
| Administrador | `admin` |
| Suporte | `support` |
| Vendedor | `seller` |
| Usuário | `user` (alias legado `student`) |

## Arquivos a **criar**

| Arquivo | Função |
|---------|--------|
| `lib/core/rbac/rbac.dart` | Barrel do módulo RBAC |
| `lib/core/rbac/rbac_catalog.dart` | Catálogo em memória (roles + permissions) |
| `lib/domain/platform/models/rbac_permission_definition.dart` | Permissão dinâmica |
| `lib/domain/platform/models/rbac_role_definition.dart` | Papel + permissionKeys |
| `lib/domain/platform/repositories/rbac_repository.dart` | Contrato Firestore |
| `lib/infrastructure/firestore/platform/firestore_rbac_repository.dart` | Persistência + seed |
| `lib/data/rbac_default_seed.dart` | Seed inicial dos 5 perfis |
| `lib/application/rbac/rbac_service.dart` | Resolução de contexto + auditoria |
| `lib/widgets/admin/rbac_gate.dart` | Guarda reutilizável por permissão/papel |
| `lib/widgets/admin/rbac_guard.dart` | Helpers imperativos (SnackBar / pop) |
| `docs/RBAC.md` | Documentação completa |

## Arquivos a **modificar**

| Arquivo | Alteração |
|---------|-----------|
| `lib/core/permissions/app_role.dart` | masterAdmin, user, aliases |
| `lib/core/permissions/app_permission.dart` | adminPanelAccess, matrix masterAdmin |
| `lib/core/permissions/permission_context.dart` | grantedPermissionKeys, hasKey |
| `lib/core/permissions/permission_checker.dart` | Catálogo dinâmico |
| `lib/core/audit/audit_event_type.dart` | access.granted / access.denied |
| `lib/core/constants/firestore_paths.dart` | Coleções RBAC |
| `lib/core/core.dart` | Export rbac |
| `lib/application/platform/platform_registry.dart` | Getter `rbac` |
| `lib/widgets/admin/admin_gate.dart` | RbacService + logs |
| `firestore.rules` | Regras platform_rbac_* |

## Arquivos **não** modificados

- `lib/main.dart`, telas de aluno, login, `AdminAuthService`, `UserProfileService`
- Fluxos OSCE, questões, flashcards, simulado

## Comportamento preservado

- Founder e `admins/{uid}` continuam com acesso admin via legado.
- Alunos sem `rbacRoles` permanecem como **Usuário** (`user`/`student`).
- Permissões novas só no Firestore — sem deploy de app.
