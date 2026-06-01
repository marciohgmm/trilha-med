# MVP Comercial — Implementação

Documentação da estrutura funcional de cobrança e controle de acesso **sem integração de gateway de pagamento** (Mercado Pago / Stripe).

> **Princípio:** o app dos alunos **não teve paywall aplicado** em flashcards, questões ou fluxos legados. O paywall só bloqueia telas onde `PaywallGate` for usado explicitamente.

---

## 1. Visão geral

| Camada | Responsabilidade |
|--------|------------------|
| **Firestore** | Planos, assinaturas, entitlements, vendedores, afiliados, cupons, parceiros, propagandas, pagamentos, auditoria |
| **Domain** | Modelos tipados + contratos de repositório |
| **Application** | `CommercialAccessService`, `CommercialAdminService`, `PlatformRegistry` |
| **UI Aluno** | `PlansPage`, `MySubscriptionPage`, links no Perfil |
| **UI Admin** | CRUD no Painel Mestre + concessão/revogação manual |
| **Paywall** | `PaywallGate` / `PaywallGuard` (opt-in) |

---

## 2. Entitlements

Chaves em `lib/core/commercial/commercial_entitlement.dart`:

| Chave | Uso |
|-------|-----|
| `premium` | Assinatura premium ativa |
| `premium_lifetime` | Acesso vitalício |
| `courtesy_access` | Cortesia |
| `beta_tester` | Beta tester |
| `seller_access` | Acesso comercial de vendedor |

**Persistência:** `users/{uid}/platform_entitlements/{id}`

**Liberam conteúdo premium:** `premium`, `premium_lifetime`, `courtesy_access`, `beta_tester`

---

## 3. Status exibido ao aluno

Enum `SubscriptionDisplayStatus`:

- `free` — Gratuito  
- `active` — Ativo  
- `expired` — Expirado  
- `lifetime` — Vitalício  
- `courtesy` — Cortesia  
- `beta` — Beta tester  

Consolidado em `CommercialAccessSnapshot` (`CommercialAccessService`).

---

## 4. Coleções Firestore

| Coleção | Documento |
|---------|-----------|
| `platform_subscription_plans` | Planos (preço, tier, benefícios) |
| `platform_subscriptions` | Assinaturas por usuário |
| `users/{uid}/platform_entitlements` | Direitos de acesso |
| `platform_sellers` | Vendedores |
| `platform_affiliates` | Afiliados |
| `platform_coupons` | Cupons |
| `platform_partnerships` | Parceiros |
| `platform_advertisements` | Propagandas |
| `platform_payments` | Pagamentos (preparado para gateway) |
| `platform_audit_logs` | Trilha de auditoria |

Paths: `lib/core/constants/firestore_paths.dart`

---

## 5. Serviços

### `CommercialAccessService`

```dart
final access = PlatformRegistry.instance.commercialAccess;
access.watchAccess(userId); // Stream<CommercialAccessSnapshot>
access.getAccess(userId);   // Future one-shot
```

Combina assinatura ativa + entitlements válidos e resolve `displayStatus`.

### `CommercialAdminService`

```dart
final admin = PlatformRegistry.instance.commercialAdmin;

await admin.grantLifetime(actorUserId: adminUid, targetUserId: studentUid);
await admin.grantCourtesy(...);
await admin.grantBetaTester(...);
await admin.grantPromotional(..., expiresAt: date);
await admin.grantLottery(..., expiresAt: date);
await admin.grantSellerAccess(...);
await admin.revokeAccess(actorUserId: adminUid, targetUserId: studentUid);
```

Registra em assinatura: `sellerId`, `affiliateId`, `couponId`, `grantSource`, `grantNotes`.  
Incrementa conversões de vendedor/afiliado e uso de cupom. Gera eventos de auditoria.

---

## 6. Paywall (opt-in)

```dart
PaywallGate(
  requiredEntitlement: CommercialEntitlementKey.premium,
  child: MinhaTelaPremium(),
)
```

Ou verificação programática:

```dart
final ok = await PaywallGuard.hasEntitlement(uid, CommercialEntitlementKey.premium);
```

**Não** envolver flashcards/questões até decisão de produto.

---

## 7. Telas do aluno

| Tela | Arquivo | Acesso |
|------|---------|--------|
| Planos | `lib/screens/commercial/plans_page.dart` | Perfil → Planos |
| Minha Assinatura | `lib/screens/commercial/my_subscription_page.dart` | Perfil → Minha Assinatura |

Catálogo estático do plano gratuito: `lib/data/commercial_plan_catalog.dart`

---

## 8. Painel Mestre — CRUD

| Módulo | Arquivo | Operações |
|--------|---------|-----------|
| Planos | `master_admin_plans_page.dart` | Criar, editar, excluir |
| Assinaturas | `master_admin_subscriptions_page.dart` | Listar + conceder/revogar |
| Cupons | `master_admin_coupons_page.dart` | CRUD |
| Vendedores | `master_admin_sellers_page.dart` | CRUD |
| Afiliados | `master_admin_affiliates_page.dart` | CRUD |
| Propagandas | `master_admin_ads_page.dart` | CRUD |
| Parceiros | `master_admin_partners_page.dart` | CRUD |

Formulários: `lib/widgets/master_admin/master_admin_commercial_forms.dart`  
Concessão manual: `lib/widgets/master_admin/master_admin_grant_access_sheet.dart`

---

## 9. Dashboard financeiro

`AdminDashboardSnapshot` inclui:

- Assinantes ativos / trial / expirados  
- Receita projetada (planos × assinaturas ativas)  
- Receita do mês (pagamentos `succeeded` — pronto para gateway)  
- Conversão por vendedor (`totalSales`)  
- Conversão por afiliado (`conversions`)  

Implementação: `_AdminDashboardRepo` em `firestore_platform_repositories.dart`

---

## 10. Regras Firestore

Arquivo: `firestore.rules`

- Planos/cupons/ads: leitura para usuários autenticados (itens ativos) ou admin  
- Assinaturas: leitura dono ou admin; criação admin ou dono (checkout futuro)  
- Entitlements: leitura dono/admin; **escrita apenas admin**  
- Vendedores/afiliados/cupons/parceiros/ads: escrita admin  

**Deploy necessário:** `firebase deploy --only firestore:rules`

---

## 11. Índices recomendados

Criar no Firebase Console se queries falharem:

```
platform_subscriptions: userId ASC, updatedAt DESC
platform_subscriptions: status ASC
platform_payments: status ASC, paidAt DESC
platform_subscription_plans: isActive ASC, sortOrder ASC
```

---

## 12. Fluxo manual (sem gateway)

1. Admin cria plano Premium no Painel Mestre  
2. (Opcional) Cadastra vendedor, afiliado, cupom  
3. Em **Assinaturas** → **Conceder acesso** → informa UID do aluno, tipo (cortesia, vitalício, beta, etc.)  
4. Aluno vê status em **Minha Assinatura**  
5. Para proteger feature: envolver widget com `PaywallGate`  

---

## 13. Próxima fase (fora deste MVP)

- [ ] Checkout Mercado Pago / Stripe  
- [ ] Webhooks → ativar assinatura automaticamente  
- [ ] Cloud Functions para agregação do dashboard  
- [ ] Aplicar paywall em features premium específicas  
- [ ] Deep links de afiliado / cupom na landing  

---

## 14. Arquivos principais criados/alterados

```
lib/core/commercial/commercial_entitlement.dart
lib/domain/platform/models/platform_entitlement.dart
lib/domain/platform/models/commercial_access_snapshot.dart
lib/data/commercial_plan_catalog.dart
lib/application/commercial/commercial_access_service.dart
lib/application/commercial/commercial_admin_service.dart
lib/application/platform/platform_registry.dart
lib/widgets/commercial/paywall_gate.dart
lib/widgets/commercial/commercial_status_chip.dart
lib/screens/commercial/plans_page.dart
lib/screens/commercial/my_subscription_page.dart
lib/widgets/master_admin/master_admin_commercial_forms.dart
lib/widgets/master_admin/master_admin_grant_access_sheet.dart
lib/infrastructure/firestore/platform/firestore_platform_repositories.dart
lib/screens/master_admin/modules/* (CRUD comercial)
lib/screens/perfil_page.dart (links Planos / Minha Assinatura)
docs/MVP_COMMERCIAL_IMPLEMENTATION.md
```

---

## 15. Teste rápido

1. **Admin:** Painel Mestre → Planos → criar plano Premium  
2. **Admin:** Assinaturas → Conceder acesso → UID do aluno → Cortesia ou Vitalício  
3. **Aluno:** Perfil → Minha Assinatura → verificar status e datas  
4. **Dev:** Envolver uma tela teste com `PaywallGate` e validar bloqueio/liberação  
5. **Admin:** Dashboard → verificar contadores e conversões  

---

*Gerado como parte do MVP comercial — maio/2026.*
