# Relatório — Painel Administrativo Mestre

**Data:** 2026-05-19  
**Escopo:** Novo módulo administrativo de plataforma (comercial, usuários, auditoria) sem alterar fluxos de alunos, auth ou telas públicas.

---

## Arquitetura reutilizada

| Componente | Caminho | Uso |
|------------|---------|-----|
| PlatformRegistry | `lib/application/platform/platform_registry.dart` | Fonte de repositórios e auditoria |
| RBAC | `RbacService`, `RbacGate`, `RbacGuard` | Permissão por módulo + logs de acesso |
| AdminGate | `lib/widgets/admin/admin_gate.dart` | Entrada administrativa (legado + RBAC) |
| Repositórios | `FirestorePlatformRepositories` | Dados `platform_*` e `users` |
| Auditoria | `PlatformAuditService` | Acesso ao painel e eventos |
| Modelo snapshot | `AdminDashboardSnapshot` | Métricas do dashboard (estendido) |

---

## Arquivos a criar

| Arquivo | Função |
|---------|--------|
| `lib/application/platform/master_admin_dashboard_service.dart` | Orquestra métricas via registry |
| `lib/screens/master_admin/master_admin_shell.dart` | Shell com navegação expansível |
| `lib/screens/master_admin/master_admin_destinations.dart` | Destinos + permissões RBAC |
| `lib/screens/master_admin/modules/master_admin_dashboard_page.dart` | Dashboard com KPIs |
| `lib/screens/master_admin/modules/master_admin_users_page.dart` | Lista usuários (leitura) |
| `lib/screens/master_admin/modules/master_admin_subscriptions_page.dart` | Assinaturas |
| `lib/screens/master_admin/modules/master_admin_plans_page.dart` | Planos |
| `lib/screens/master_admin/modules/master_admin_sellers_page.dart` | Vendedores |
| `lib/screens/master_admin/modules/master_admin_affiliates_page.dart` | Afiliados |
| `lib/screens/master_admin/modules/master_admin_coupons_page.dart` | Cupons |
| `lib/screens/master_admin/modules/master_admin_partners_page.dart` | Parceiros |
| `lib/screens/master_admin/modules/master_admin_ads_page.dart` | Propagandas |
| `lib/screens/master_admin/modules/master_admin_audit_page.dart` | Auditoria |
| `lib/screens/master_admin/modules/master_admin_settings_page.dart` | Configurações / RBAC |
| `lib/widgets/master_admin/master_admin_stat_card.dart` | Card de métrica |
| `lib/widgets/master_admin/master_admin_module_scaffold.dart` | Layout padrão dos módulos |
| `lib/widgets/master_admin/master_admin_empty_module.dart` | Estado vazio / preparado |
| `docs/MASTER_ADMIN_PANEL.md` | Documentação completa |

---

## Arquivos a alterar

| Arquivo | Alteração |
|---------|-----------|
| `lib/domain/platform/models/admin_dashboard_snapshot.dart` | KPIs: usuários, admins, receita projetada |
| `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart` | `_AdminDashboardRepo` ampliado |
| `lib/application/platform/platform_registry.dart` | Getter `masterAdminDashboard` |
| `lib/core/permissions/app_permission.dart` | `platform.settings` |
| `lib/data/rbac_default_seed.dart` | Label da nova permissão |
| `lib/screens/admin_page.dart` | Botão opcional para o painel mestre (aditivo) |

---

## Impacto esperado

| Área | Impacto |
|------|---------|
| Alunos / home / login | **Nenhum** — painel só acessível via `AdminPage` existente |
| AdminPage (conteúdo) | **Aditivo** — um card “Painel Mestre” |
| Firestore | Leituras `count()` e listas em coleções já previstas nas rules `platform_*` |
| Performance | Dashboard faz várias contagens na abertura; aceitável para admin |
| Pagamentos | **Nenhum** — UI preparada, sem Stripe/MP |

---

## Dependências

- `firebase_auth`, `cloud_firestore`, `flutter/material.dart`
- `PlatformRegistry`, `RbacService`, `AdminGate`, `RbacGate`
- Coleções: `users`, `admins`, `platform_*`, `platform_audit_logs`
- Permissões existentes: `dashboard.view`, `user.manage`, `subscription.manage`, etc.
- Nova permissão: `platform.settings` (configurações)

---

## Mapa módulo → permissão

| Módulo | Permissão RBAC |
|--------|----------------|
| Dashboard | `dashboard.view` |
| Usuários | `user.manage` |
| Assinaturas | `subscription.manage` |
| Planos | `subscription.manage` |
| Vendedores | `seller.manage` |
| Afiliados | `affiliate.manage` |
| Cupons | `coupon.manage` |
| Parceiros | `partnership.manage` |
| Propagandas | `ad.manage` |
| Auditoria | `audit.read` |
| Configurações | `platform.settings` |

---

## Próximo passo

Implementação conforme este relatório.
