# Relatório prévio — Unificação administrativa (R1 + F4)

**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `RBAC.md`, `RBAC_IMPLEMENTATION_REPORT.md`  
**Data:** 2026-05-19  
**Status:** Pré-implementação (base para execução)

---

## Problema (R1 + F4)

| ID | Situação atual |
|----|----------------|
| **R1** | `AdminAuthService.resolveAccess` só considera founder + `admins/{uid}` — ignora `users.isAdmin` e `rbacRoles` |
| **R2** (relacionado) | Home usa só `resolveAccess` — contas só com `isAdmin` não abrem admin pelo gesto oculto |
| **F4** | Três fontes: `admins`, `users.isAdmin`, `rbacRoles` — sem sync nem auditoria unificada em grant/revoke |

`AdminGate` já usa `legacy OR rbac`, mas **legado incompleto** gera falso negativo na home.

---

## Objetivo

RBAC como **fonte principal** de permissões administrativas, com **camada de compatibilidade** que:

1. Mapeia founder / admins / isAdmin → papéis RBAC equivalentes  
2. Centraliza resolução em um serviço único  
3. Alinha Home, `AdminAuthService`, `AdminGate`, Painel Mestre  
4. Audita concessão/remoção de acesso admin  

**Sem remover** mecanismos legados (coleção `admins`, `isAdmin`, e-mail founder).

---

## Mapeamento (Fase 1)

| Sinal legado | Papel RBAC implícito | Quando aplicar |
|--------------|----------------------|----------------|
| Founder (`marciohgmm@gmail.com`) | `masterAdmin` | Se `rbacRoles` vazio |
| `admins/{uid}` existe | `admin` | Se `rbacRoles` vazio |
| `users.isAdmin == true` | `admin` | Se `rbacRoles` vazio |
| `rbacRoles` já preenchido | Respeitar Firestore | Nunca sobrescrever |

Persistência opcional: gravar `rbacRoles` uma vez (merge) para alinhar Firestore ao RBAC — **não** remove `admins` nem `isAdmin`.

---

## Arquivos a criar

| Arquivo | Função |
|---------|--------|
| `lib/application/admin/admin_legacy_compat.dart` | Mapeamento + sync não destrutivo |
| `lib/application/admin/admin_access_service.dart` | Resolução única + auditoria grant/revoke |
| `docs/ADMIN_UNIFICATION.md` | Documentação + remoção futura + testes |

## Arquivos a alterar

| Arquivo | Alteração |
|---------|-----------|
| `lib/application/rbac/rbac_service.dart` | `resolveContext` via sinais legados completos (sem `resolveAccess` circular) |
| `lib/services/auth/admin_auth_service.dart` | Delegar `resolveAccess`; audit em grant/revoke |
| `lib/widgets/admin/admin_gate.dart` | Só `AdminAccessService` |
| `lib/screens/home_page.dart` | Só `AdminAccessService` |

**Sem alterar:** login, `main.dart`, fluxo aluno, regras Firestore de auth.

---

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Escrita indesejada em `rbacRoles` | Só se lista vazia |
| Ciclo de dependência AdminAuth ↔ Rbac | `resolveContext` não chama `resolveAccess` |
| Founder perde bypass | `masterAdmin` + `canAccessAdminPanel` inalterado |
| Painel Mestre quebra | Usa `RbacService.resolveContext` já alinhado |

---

## Critério de sucesso

- Conta só `isAdmin`: abre admin na home **e** no `AdminGate`  
- Founder: acesso total  
- `admins/{uid}`: acesso admin  
- `grantAdmin` / `revokeAdmin`: log em `platform_audit_logs`  
- Painel Mestre inalterado para admins com `dashboard.view`
