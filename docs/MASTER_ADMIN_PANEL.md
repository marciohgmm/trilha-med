# Painel Administrativo Mestre — Documentação

## Visão geral

O **Painel Mestre** é um módulo administrativo separado do painel de conteúdo (`AdminPage`). Ele centraliza gestão da plataforma comercial (usuários, assinaturas, vendedores, auditoria) usando:

- `PlatformRegistry` — repositórios Firestore `platform_*`
- `RbacService` / `RbacGate` — permissão por módulo
- `PlatformAuditService` — logs de acesso e ações
- `AdminGate` — entrada administrativa (legado + RBAC)

**Não altera:** login, fluxo dos alunos, telas públicas nem o painel de flashcards/questões.

---

## Como acessar

1. Entrar como administrador (founder, `admins`, `users.isAdmin` ou RBAC).
2. Abrir **Área Administrativa** (gesto/botão oculto na home).
3. Tocar em **Painel Mestre da Plataforma** (requer `dashboard.view`).

---

## Estrutura de arquivos

```
lib/screens/master_admin/
  master_admin_shell.dart          # Shell + navegação
  master_admin_destinations.dart   # Módulos + permissões
  modules/
    master_admin_dashboard_page.dart
    master_admin_users_page.dart
    ... (11 módulos)

lib/widgets/master_admin/
  master_admin_stat_card.dart
  master_admin_module_scaffold.dart
  master_admin_empty_module.dart

lib/application/platform/
  master_admin_dashboard_service.dart
```

---

## Módulos e permissões

| Módulo | Rota auditoria | Permissão |
|--------|----------------|-----------|
| Dashboard | `master.dashboard` | `dashboard.view` |
| Usuários | `master.users` | `user.manage` |
| Assinaturas | `master.subscriptions` | `subscription.manage` |
| Planos | `master.plans` | `subscription.manage` |
| Vendedores | `master.sellers` | `seller.manage` |
| Afiliados | `master.affiliates` | `affiliate.manage` |
| Cupons | `master.coupons` | `coupon.manage` |
| Parceiros | `master.partners` | `partnership.manage` |
| Propagandas | `master.ads` | `ad.manage` |
| Auditoria | `master.audit` | `audit.read` |
| Configurações | `master.settings` | `platform.settings` |

Cada tela é envolvida por `RbacGate` com a permissão correspondente. O menu lateral/inferior só exibe módulos permitidos ao usuário.

---

## Dashboard — métricas

Carregadas por `PlatformRegistry.instance.masterAdminDashboard.loadSnapshot()`:

| Métrica | Fonte |
|---------|--------|
| Total de usuários | `users` count |
| Usuários ativos (30d) | `users` onde `updatedAt` ≥ 30 dias |
| Novos usuários (30d) | `users` onde `createdAt` ≥ 30 dias |
| Administradores | `admins` + `users.isAdmin` |
| Vendedores / Afiliados | `platform_sellers` / `platform_affiliates` ativos |
| Assinaturas | `platform_subscriptions` |
| Receita projetada | Soma `priceMonthly` dos planos das assinaturas ativas (até 200) |
| Auditoria recente | Últimos 8 em `platform_audit_logs` |

---

## Auditoria

- Abertura do shell: `adminAction` em `master_admin` / `shell.open`
- Cada módulo: `RbacGate` → `access.granted` ou `access.denied`
- Listagem completa na aba **Auditoria** via `auditLogs.watchRecent()`

---

## Expansão futura

### Novo módulo no menu

1. Criar página em `lib/screens/master_admin/modules/`.
2. Adicionar entrada em `MasterAdminDestinations.all`.
3. (Opcional) Nova permissão em Firestore `platform_rbac_permissions` — sem rebuild se só no Firestore.
4. Atribuir permissão ao papel em `platform_rbac_roles`.

### Pagamentos (Stripe / Mercado Pago)

- Coleções já existem: `platform_payments`, `platform_subscriptions`.
- Implementar gateway em `lib/infrastructure/` e registrar em `PlatformRegistry`.
- UI de checkout **fora** do fluxo dos alunos até feature flag explícita.

---

## Deploy

Garantir rules para leitura/escrita admin em `platform_*` e índices se usar `orderBy` adicionais:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

---

## Relatório de implementação

Ver `docs/MASTER_ADMIN_PANEL_REPORT.md`.
