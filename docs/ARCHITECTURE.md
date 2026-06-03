# Arquitetura — Trilha Med

Documentação da estrutura do aplicativo e do **módulo plataforma** preparado para crescimento comercial.

---

## 1. Visão em camadas

```
┌─────────────────────────────────────────────────────────────┐
│  UI (lib/screens, lib/widgets) — existente, inalterado        │
├─────────────────────────────────────────────────────────────┤
│  Serviços legados (lib/services/*) — Firebase direto        │
├─────────────────────────────────────────────────────────────┤
│  Application (lib/application/platform) — orquestração nova │
├─────────────────────────────────────────────────────────────┤
│  Domain (lib/domain/platform) — modelos + contratos         │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure (lib/infrastructure/firestore/platform)     │
├─────────────────────────────────────────────────────────────┤
│  Core (lib/core) — permissões, auditoria, constantes        │
├─────────────────────────────────────────────────────────────┤
│  Firebase (Auth, Firestore, Storage)                        │
└─────────────────────────────────────────────────────────────┘
```

**Regra de ouro:** código legado **não importa** `PlatformRegistry` até uma feature ser ligada explicitamente.

---

## 2. Estrutura de pastas (novo)

```
lib/
├── core/
│   ├── constants/firestore_paths.dart    # Nomes de coleções
│   ├── base/firestore_entity.dart        # Contrato toMap / datas
│   ├── permissions/                      # RBAC preparatório
│   └── audit/                            # AuditLogEntry, AuditEventType
├── domain/platform/
│   ├── enums/platform_enums.dart
│   ├── models/                           # 11 entidades
│   └── repositories/platform_repository_contracts.dart
├── infrastructure/firestore/platform/
│   └── firestore_platform_repositories.dart
├── application/platform/
│   ├── platform_registry.dart            # Singleton de acesso
│   └── platform_audit_service.dart
docs/
├── EXPANSION_PLAN.md                     # Análise + plano
└── ARCHITECTURE.md                       # Este arquivo
```

---

## 3. Domínios do módulo plataforma

| Domínio | Modelo | Coleção Firestore |
|---------|--------|-------------------|
| Planos | `SubscriptionPlan` | `platform_subscription_plans` |
| Assinaturas | `Subscription` | `platform_subscriptions` |
| Pagamentos | `Payment` | `platform_payments` |
| Vendedores | `Seller` | `platform_sellers` |
| Afiliados | `Affiliate` | `platform_affiliates` |
| Cupons | `Coupon` | `platform_coupons` |
| Parcerias | `Partnership` | `platform_partnerships` |
| Propagandas | `Advertisement` | `platform_advertisements` |
| Auditoria | `AuditLogEntry` | `platform_audit_logs` |
| Notificações | `UserNotification` | `users/{uid}/platform_notifications` |
| Usuário+ | `PlatformUserExtension` | campos em `users/{uid}` |
| Dashboard | `AdminDashboardSnapshot` | agregado em runtime |

---

## 4. Permissões (RBAC)

### Papéis — `AppRole`

- `student`, `admin`, `seller`, `affiliate`, `partner`, `finance`, `support`

### Permissões — `AppPermission`

Ex.: `content.read`, `subscription.manage`, `payment.refund`, `dashboard.view`, …

### Matriz padrão — `RolePermissionMatrix`

Define permissões por papel até existir configuração dinâmica no Firestore.

### Uso futuro

```dart
final ctx = PermissionChecker.fromUserDoc(
  userId: uid,
  userData: userDoc.data(),
  isFounder: AdminAuthService.isFounderUser(user),
  isLegacyAdmin: adminResult.allowed,
);
if (ctx.has(AppPermission.couponManage)) { ... }
```

**Compatível** com `AdminAuthService` atual (`isLegacyAdmin` = founder | admins | users.isAdmin).

---

## 5. Auditoria

- Serviço: `PlatformAuditService`
- Logs **append-only** em `platform_audit_logs`
- Regra Firestore: qualquer usuário autenticado pode **criar**; só admin **lê**; **update/delete** negados

```dart
PlatformRegistry.instance.audit.log(
  eventType: AuditEventType.couponApplied,
  actorUserId: uid,
  entityType: 'coupon',
  entityId: couponId,
);
```

---

## 6. Repositórios e registry

### Contratos

`lib/domain/platform/repositories/platform_repository_contracts.dart`

### Implementação

`FirestorePlatformRepositories` — um agrupador com implementações privadas por coleção.

### Acesso

```dart
import 'package:flutter_application_1/application/platform/platform_registry.dart';

final repos = PlatformRegistry.instance.repositories;

// Exemplos (quando integrar UI):
repos.subscriptionPlans.watchActivePlans();
repos.subscriptions.watchActiveForUser(userId);
repos.coupons.getByCode('REVALIDA10');
repos.dashboard.loadSnapshot();
```

---

## 7. Firestore — regras novas

Arquivo: `firestore.rules` (seção **Plataforma**)

| Coleção | Leitura | Escrita |
|---------|---------|---------|
| Planos ativos | Usuários logados | Admin |
| Assinaturas | Dono ou admin | Dono (create) / admin |
| Pagamentos | Dono ou admin | Admin (update); create dono/admin |
| Sellers, affiliates, coupons, ads | Catálogo (ativos) ou admin | Admin |
| Partnerships | Admin | Admin |
| Audit logs | Admin | Create autenticado |
| Notificações usuário | Dono / admin | Admin ou create para o dono |

**Deploy:** `firebase deploy --only firestore:rules,firestore:indexes`

---

## 8. Sistema legado (inalterado)

| Feature | Pasta | Persistência |
|---------|-------|--------------|
| Flashcards | `services/firebase_service` | `flashcards` |
| Questões / Simulado | `questao_service`, `simulado_service` | `questoes`, `users/...` |
| OSCE | `services/osce/*` | `osce_*` |
| Fase prática | `practical_phase_*` + repository | `practical_phase_*` |
| Live events | `live_event_service` | `live_events` |
| Admin | `AdminAuthService`, `AdminGate` | `admins`, `users.isAdmin` |
| Suporte | reports | `notificacoes_admin` |
| Broadcast | `global_message_service` | `global_messages` |

---

## 9. Diferença: notificações

| Canal | Coleção | Uso |
|-------|---------|-----|
| Suporte / reports | `notificacoes_admin` | Erros de questão, perfil — **já em produção** |
| In-app usuário | `users/.../platform_notifications` | Promoções, assinatura, pagamento — **novo** |
| Push (futuro) | FCM + `LiveEventNotificationService` | Stubs existentes |

---

## 10. Integração gradual (roadmap)

1. **Fase B** — Admin: CRUD planos/cupons usando `PlatformRegistry`
2. **Fase C** — Cloud Functions + webhook pagamento → `platform_payments`
3. **Fase D** — Tela dashboard consumindo `AdminDashboardRepository`
4. **Fase E** — Paywall: `watchActiveForUser` antes de simulado/OSCE premium
5. **Fase F** — Migrar `usuarios` → `users` progresso (projeto separado)

---

## 11. Testes

```dart
// Exemplo de override
PlatformRegistry.instance.overrideForTesting(mockRepos);
```

---

## 12. Checklist de não-regressão

- [ ] `main.dart` não referencia `PlatformRegistry`
- [ ] Nenhuma tela em `lib/screens/` importa `domain/platform` ou `application/platform`
- [ ] Serviços legados intactos
- [ ] Regras antigas (`flashcards`, `osce_*`, …) preservadas no `firestore.rules`
- [ ] `flutter analyze` sem erros nos novos pacotes

---

## 13. Referências rápidas

| Preciso de… | Arquivo |
|-------------|---------|
| Nome da coleção | `lib/core/constants/firestore_paths.dart` |
| Modelo de assinatura | `lib/domain/platform/models/subscription.dart` |
| Interface repositório | `lib/domain/platform/repositories/platform_repository_contracts.dart` |
| Implementação Firestore | `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart` |
| Entrada única | `lib/application/platform/platform_registry.dart` |
| Plano de expansão | `docs/EXPANSION_PLAN.md` |
