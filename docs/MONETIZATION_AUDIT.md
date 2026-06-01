# Auditoria de monetização — Trilha Med / Revalida Cards

**Data:** 2026-05-19  
**Modo:** Somente leitura — **nenhum código alterado**  
**Escopo:** Plano comercial, pagamentos, paywall, Painel Mestre, Firestore, RBAC

Documentos relacionados: `docs/ARCHITECTURE.md`, `docs/MASTER_ADMIN_PANEL.md`, `docs/FINAL_AUDIT_POST_IMPLEMENTATION.md`, `docs/TECHNICAL_AUDIT.md`.

---

## Sumário executivo

| Estado | Veredito |
|--------|----------|
| **Infraestrutura de dados** | Coleções `platform_*`, modelos de domínio, repositórios Firestore e rules **existem no repositório** |
| **Painel administrativo** | 11 módulos de **leitura/listagem** no Painel Mestre; **sem CRUD** nem checkout |
| **Fluxo do aluno** | **Zero paywall** — flashcards, questões, OSCE, live events acessíveis a qualquer usuário autenticado |
| **Pagamentos** | Enum `PaymentProvider` prevê `stripe` e `mercado_pago`; **nenhum SDK, webhook ou Cloud Function** |
| **Monetização operacional** | **Não é possível cobrar assinatura hoje** sem trabalho adicional (backend + UI aluno + enforcement) |

**Conclusão:** A plataforma está **preparada arquiteturalmente** (camada `domain` + `PlatformRegistry`), mas a monetização está na fase **“schema + admin read-only”**, não **“produto vendável”**.

---

## 1. O que já existe pronto para monetização

### 1.1 Modelo de dados (domínio)

| Artefato | Caminho | Status |
|----------|---------|--------|
| Planos | `lib/domain/platform/models/subscription_plan.dart` | Completo (`name`, preços mensal/anual, `currency`, `featureKeys`, `isActive`, `sortOrder`) |
| Assinaturas | `lib/domain/platform/models/subscription.dart` | Completo (`userId`, `planId`, `status`, períodos, `couponId`, `externalProviderId`, `metadata`) |
| Pagamentos | `lib/domain/platform/models/payment.dart` | Completo (`provider`, `providerPaymentId`, vínculo seller/affiliate/coupon) |
| Vendedores | `lib/domain/platform/models/seller.dart` | Completo |
| Afiliados | `lib/domain/platform/models/affiliate.dart` | Completo |
| Cupons | `lib/domain/platform/models/coupon.dart` | Completo |
| Parcerias | `lib/domain/platform/models/partnership.dart` | Completo |
| Propagandas | `lib/domain/platform/models/advertisement.dart` | Completo (placements definidos) |
| Extensão usuário | `lib/domain/platform/models/platform_user_extension.dart` | Campos comerciais (`sellerId`, `affiliateId`, `activeSubscriptionId`) |
| Enums | `lib/domain/platform/enums/platform_enums.dart` | `SubscriptionStatus`, `PaymentStatus`, `PaymentProvider` (`manual`, `stripe`, `mercado_pago`, `apple`, `google`) |

### 1.2 Persistência Firestore (repositórios)

Implementação: `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart`

| Repositório | Operações implementadas |
|-------------|-------------------------|
| `subscriptionPlans` | `watchActivePlans`, `getById`, `save`, `delete` |
| `subscriptions` | `watchActiveForUser`, `getById`, `save` |
| `payments` | `watchForUser`, `save` |
| `sellers` | `watchAll`, `getByUserId`, `save` |
| `affiliates` | `watchAll`, `getByCode`, `save` |
| `coupons` | `watchActive`, `getByCode`, `save` |
| `partnerships` | `watchAll`, `save` |
| `advertisements` | `watchByPlacement`, `save` |
| `auditLogs` | `append`, `watchRecent` |
| `users` (extensão) | `getExtension`, `mergeExtension` |
| `dashboard` | `loadSnapshot` (métricas comerciais) |

### 1.3 Registro e serviços de aplicação

| Componente | Caminho | Função |
|------------|---------|--------|
| `PlatformRegistry` | `lib/application/platform/platform_registry.dart` | Singleton lazy — **não inicializado em `main.dart`** |
| `MasterAdminDashboardService` | `lib/application/platform/master_admin_dashboard_service.dart` | Agregados comerciais |
| `PlatformAuditService` | `lib/application/platform/platform_audit_service.dart` | Auditoria append-only |
| Eventos de audit | `lib/core/audit/audit_event_type.dart` | `subscription.created`, `subscription.canceled` (tipos definidos) |

### 1.4 Segurança Firestore (rules locais)

Arquivo: `firestore.rules` (seção Plataforma, L394–494)

- Planos ativos legíveis por usuários autenticados
- Assinaturas/pagamentos: dono ou `isAppAdmin()`
- Catálogo sellers/affiliates/coupons/ads: leitura autenticada (com filtros `isActive` onde aplicável)
- Parcerias e audit logs: admin
- `users/{uid}/platform_entitlements`: read/write owner ou admin (subcoleção)

### 1.5 Índices Firestore

Arquivo: `firestore.indexes.json`

- `platform_subscriptions` (`userId` + `status`)
- `platform_payments` (`userId` + `paidAt`)
- `platform_advertisements` (`placement` + `isActive` + `priority`)
- **Ausente:** índice composto para `platform_subscription_plans` (`isActive` + `sortOrder`) — pode ser exigido em runtime

### 1.6 RBAC comercial

- Permissões e matriz papel→permissão em `lib/core/permissions/app_permission.dart` e `app_role.dart`
- Seed Firestore RBAC inclui chaves comerciais (`RbacDefaultSeed`)

### 1.7 Painel Mestre (admin)

Entrada: `AdminPage` → `RbacGuard` (`dashboard.view`) → `MasterAdminShell`

11 módulos com listagem/stream e permissões RBAC por rota (ver §7).

### 1.8 Diagnóstico Firestore (admin)

`MasterAdminDiagnosticsService` — sondas `platform_*` ao abrir Painel Mestre (não afeta alunos).

---

## 2. O que existe parcialmente implementado

| Área | O que há | O que falta |
|------|----------|-------------|
| **Planos** | Modelo + repo `save`/`delete` + tela lista planos **ativos** | UI criar/editar plano; seed de planos; IDs externos Stripe/MP |
| **Assinaturas** | Modelo + `watchActiveForUser` + listagem admin | Nenhum fluxo cria assinatura após pagamento; aluno não consulta assinatura |
| **Pagamentos** | Modelo + `save` + rules | Sem tela admin de pagamentos; sem reconciliação webhook |
| **Cupons / Afiliados** | `getByCode` no repo | Sem checkout que aplique cupom; sem tracking de clique/conversão |
| **Vendedores** | Modelo + atribuição em `Payment` | Sem portal vendedor; sem comissão automática |
| **Propagandas** | `watchByPlacement` + placements enum | **Nenhuma tela de aluno** consome ads |
| **Parcerias** | Modelo + listagem admin | Sem vínculo com checkout ou entitlements |
| **Entitlements** | Path + rules `users/{uid}/platform_entitlements` | **Sem modelo Dart**, sem repositório, sem leitura no app |
| **PlatformUserExtension** | Modelo + merge em `users` | App legado não usa campos comerciais no perfil |
| **featureKeys** em planos | Campo no modelo | Sem mapa feature→tela; sem gate no código |
| **Deploy produção** | Rules/indexes no repo | Deploy coordenado pode estar pendente (ver auditorias D1) |
| **RBAC dinâmico** | Firestore `platform_rbac_*` | Seed client-side; papéis comerciais (`seller`, `affiliate`) sem UI de atribuição |

### 2.1 Conteúdo “grátis” hoje (impacto na monetização)

Rules atuais permitem leitura total para `isSignedIn()`:

- `flashcards` — coleção inteira
- `questoes` — coleção inteira

Ou seja: **não há conteúdo premium protegido por assinatura** no Firestore nem no cliente.

### 2.2 Risco de fraude (rules)

`platform_subscriptions` permite **create** pelo próprio usuário (`isSubscriptionOwnerOnCreate`) sem validação de pagamento (`TECHNICAL_AUDIT.md` S6). Qualquer cliente poderia criar assinatura `active` até o paywall ser fechado no servidor.

---

## 3. O que falta para cobrar assinatura dos usuários

### 3.1 Produto / UX aluno

| # | Item | Prioridade |
|---|------|------------|
| 1 | Tela **Planos / Assinar** (lista `watchActivePlans`, preço BRL) | P0 |
| 2 | **Checkout** (redirect ou in-app) ligado a gateway | P0 |
| 3 | **Paywall** — verificar assinatura ativa antes de features premium | P0 |
| 4 | Definir **o que é pago** (ex.: simulados, OSCE ilimitado, live premium, fase prática) | P0 |
| 5 | Tela **Minha assinatura** no Perfil (`watchActiveForUser`) | P1 |
| 6 | Estados: trial, past_due, cancelado, expirado — UX clara | P1 |
| 7 | Notificações (`platform_notifications`) — renovação, falha pagamento | P2 |

### 3.2 Backend / confiança

| # | Item | Prioridade |
|---|------|------------|
| 1 | **Cloud Functions** (ou backend) para criar/atualizar assinatura **somente após pagamento confirmado** | P0 |
| 2 | Remover ou restringir `create` client-side em `platform_subscriptions` | P0 |
| 3 | Webhook idempotente (payment → subscription → entitlement opcional) | P0 |
| 4 | Modelo + repo **`platform_entitlements`** ou uso de `featureKeys` + assinatura | P1 |
| 5 | Sincronizar `users.activeSubscriptionId` / extensão comercial | P1 |
| 6 | Restringir leitura `flashcards`/`questoes` por plano (rules + índices) | P1–P2 |

### 3.3 Admin / operação

| # | Item | Prioridade |
|---|------|------------|
| 1 | CRUD planos no Painel Mestre (hoje só lista) | P1 |
| 2 | Tela pagamentos + reembolso (`payment.refund` sem UI) | P1 |
| 3 | Concessão manual (suporte) com audit trail | P2 |

### 3.4 Infra

| # | Item |
|---|------|
| 1 | `firebase deploy --only firestore:rules,firestore:indexes` |
| 2 | Conta gateway em produção (MP e/ou Stripe) |
| 3 | Variáveis de ambiente / secrets (Functions) |

---

## 4. O que falta para integrar Mercado Pago

Mercado Pago é o caminho natural para **BRL** e público Brasil.

### 4.1 Já preparado no código

- `PaymentProvider.mercadoPago` → key `'mercado_pago'`
- `Payment.providerPaymentId`, `metadata` para IDs MP
- `Subscription.externalProviderId` para assinatura/preapproval MP
- Moeda padrão `BRL` em planos

### 4.2 Não existe

| Item | Detalhe |
|------|---------|
| SDK / pacote | `pubspec.yaml` **não** inclui `mercadopago_sdk`, `webview` checkout dedicado, etc. |
| Cloud Functions | Pasta `functions/` **ausente** — webhooks IPN/notification URL |
| Checkout | Preference API / Checkout Pro / assinaturas MP |
| Mapeamento plano ↔ `preapproval_plan_id` ou item MP | Campo não existe em `SubscriptionPlan` (só `featureKeys`) |
| PIX / boleto / cartão | Fluxo UI + confirmação assíncrona |
| Conciliação | Atualizar `platform_payments.status` e criar `platform_subscriptions` no webhook |
| Cupom MP vs cupom interno | `Coupon` interno não integrado ao checkout MP |
| Testes sandbox | Credenciais `TEST-`, usuários de teste |
| Compliance | Termos, nota fiscal, cancelamento — fora do código |

### 4.3 Checklist mínimo Mercado Pago

1. Criar app no [Mercado Pago Developers](https://www.mercadopago.com.br/developers).
2. Firebase Functions (Node) ou Cloud Run:
   - `POST /create-checkout` — cria preferência com `planId`, `userId`, `couponCode?`
   - `POST /webhooks/mercadopago` — valida assinatura, atualiza Firestore
3. Campos extras sugeridos em `SubscriptionPlan`: `mercadoPagoPlanId`, `mercadoPagoItemId`
4. Flutter: `url_launcher` (já no projeto) ou WebView para Checkout Pro
5. Fechar rules: assinatura só via Admin SDK / Function

---

## 5. O que falta para integração Stripe

Stripe é **secundário** para Revalida Brasil, mas o enum já prevê.

### 5.1 Já preparado

- `PaymentProvider.stripe`
- Modelos compatíveis com `providerPaymentId`, assinatura externa, metadata

### 5.2 Não existe

| Item | Detalhe |
|------|---------|
| Pacote | Sem `flutter_stripe` / `stripe_js` |
| Stripe Products / Prices | Sem campos `stripePriceId` / `stripeProductId` em `SubscriptionPlan` |
| Checkout Session / Customer Portal | Sem endpoints |
| Webhooks | `checkout.session.completed`, `invoice.paid`, `customer.subscription.deleted` |
| Billing portal (cancelar/alterar cartão) | Sem UI |
| Moeda | Planos em BRL — Stripe suporta, mas taxas/UX Brasil vs MP |

### 5.3 Quando preferir Stripe

- Público internacional ou cartões estrangeiros
- Assinaturas recorrentes com Customer Portal maduro
- Mesma stack se já usar Stripe em outros produtos

**Esforço comparable ao MP:** Functions + webhooks + campos externos no plano + tela checkout.

---

## 6. Estrutura atual por domínio comercial

### 6.1 Planos (`platform_subscription_plans`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `SubscriptionPlan` |
| **Campos chave** | `priceMonthly`, `priceYearly`, `currency`, `featureKeys[]`, `isActive`, `sortOrder` |
| **Repo** | CRUD completo |
| **Admin UI** | Lista somente planos **ativos** (`watchActivePlans`) |
| **Aluno** | Não exibe planos |
| **Rules** | Read: signedIn + (admin ou `isActive`); Write: admin |

### 6.2 Assinaturas (`platform_subscriptions`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Subscription` |
| **Status** | `trialing`, `active`, `past_due`, `canceled`, `expired` |
| **Repo** | `watchActiveForUser(userId)` — **não usado no app aluno** |
| **Admin UI** | Stream limit 80 (todos os docs visíveis ao admin) |
| **Rules** | Read/write owner ou admin; **create permitido ao owner** (risco) |

### 6.3 Vendedores (`platform_sellers`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Seller` — `userId`, comissão %, totais |
| **Repo** | Listagem + save |
| **Admin UI** | Lista read-only |
| **App aluno** | Não usa |
| **Pagamento** | `Payment.sellerId` previsto, sem pipeline |

### 6.4 Afiliados (`platform_affiliates`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Affiliate` — `code`, métricas clicks/conversions |
| **Repo** | `getByCode`, listagem |
| **Admin UI** | Lista read-only |
| **App aluno** | Sem deep link `?ref=CODE` |
| **Usuário** | `PlatformUserExtension.referredByAffiliateId` — não populado |

### 6.5 Cupons (`platform_coupons`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Coupon` — percent/fixed, validade, `applicablePlanIds`, vínculo seller/affiliate |
| **Repo** | `getByCode`, `watchActive` |
| **Admin UI** | Lista cupons **ativos** only |
| **Checkout** | Não aplicado |

### 6.6 Propagandas (`platform_advertisements`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Advertisement` — `placement`, priority, impressões/cliques |
| **Placements** | `home_banner`, `study_interstitial`, `osce_lobby`, `practical_phase` |
| **Repo** | `watchByPlacement` |
| **Admin UI** | Lista limit 50 (sem filtro `isActive` na query — pode conflitar com rules) |
| **App aluno** | **Nenhum widget** consome `watchByPlacement` |

### 6.7 Parcerias (`platform_partnerships`)

| Aspecto | Detalhe |
|---------|---------|
| **Modelo** | `Partnership` — revenue share, `allowedPlanIds` |
| **Repo** | Listagem + save |
| **Admin UI** | Lista read-only |
| **Integração** | Não ligada a checkout ou ads (`partnershipId` em ad existe no modelo) |

### 6.8 Entitlements (`users/{uid}/platform_entitlements`)

| Aspecto | Detalhe |
|---------|---------|
| **Firestore** | Subcoleção definida em `FirestorePaths.userPlatformEntitlements` |
| **Rules** | Read owner/admin; write admin |
| **Código Dart** | **Sem modelo, sem repositório, sem UI** |
| **Uso previsto** | Direitos granulares (ex.: `feature.osce.unlimited` até `expiresAt`) — documentado em `FINAL_AUDIT` como futuro |

**Alternativa atual:** `SubscriptionPlan.featureKeys` + assinatura ativa inferida via `watchActiveForUser` — **não implementado no cliente**.

---

## 7. Telas administrativas prontas

Acesso: **AdminGate** + Painel Mestre + **RbacGate** por módulo.

| Módulo | Arquivo | Pronto | Capacidades |
|--------|---------|--------|-------------|
| Dashboard | `master_admin_dashboard_page.dart` | Sim | Métricas + audit recente; refresh |
| Usuários | `master_admin_users_page.dart` | Sim | Lista 100 users (read-only) |
| Assinaturas | `master_admin_subscriptions_page.dart` | Parcial | Lista stream; empty state com roadmap |
| Planos | `master_admin_plans_page.dart` | Parcial | Lista planos ativos; empty state |
| Vendedores | `master_admin_sellers_page.dart` | Parcial | Lista; empty state |
| Afiliados | `master_admin_affiliates_page.dart` | Parcial | Lista; empty state |
| Cupons | `master_admin_coupons_page.dart` | Parcial | Lista ativos; empty state |
| Parceiros | `master_admin_partners_page.dart` | Parcial | Lista; empty state |
| Propagandas | `master_admin_ads_page.dart` | Parcial | Lista; empty state |
| Auditoria | `master_admin_audit_page.dart` | Sim | Stream 100 eventos |
| Configurações | `master_admin_settings_page.dart` | Sim | RBAC info, diagnóstico Firestore, reload catálogo |

**Não existe:** telas CRUD (formulários criar/editar), módulo **Pagamentos**, telas **Reembolso**, portal **Vendedor/Afiliado**.

**Legado (conteúdo, não monetização):** `AdminPage` — flashcards, questões, OSCE, live events, mensagem global.

---

## 8. Coleções Firestore (monetização)

| Coleção / path | Existe no código | Rules (repo) | Dados seed | Usada app aluno |
|----------------|-------------------|--------------|------------|-----------------|
| `platform_subscription_plans` | Sim | Sim | Não (manual) | Não |
| `platform_subscriptions` | Sim | Sim | Não | Não |
| `platform_payments` | Sim | Sim | Não | Não |
| `platform_sellers` | Sim | Sim | Não | Não |
| `platform_affiliates` | Sim | Sim | Não | Não |
| `platform_coupons` | Sim | Sim | Não | Não |
| `platform_partnerships` | Sim | Sim | Não | Não |
| `platform_advertisements` | Sim | Sim | Não | Não |
| `platform_audit_logs` | Sim | Sim | Append app | Não |
| `users/{uid}/platform_notifications` | Sim | Sim | Não | Não |
| `users/{uid}/platform_entitlements` | Path + rules | Sim | Não | Não |
| `platform_rbac_roles` | Sim | Sim | Seed RBAC | Indireto (admin) |
| `platform_rbac_permissions` | Sim | Sim | Seed RBAC | Indireto (admin) |

**Conteúdo gratuito hoje (impacto receita):** `flashcards`, `questoes` — leitura aberta a autenticados.

---

## 9. Permissões RBAC para monetização

### 9.1 Permissões comerciais (`AppPermission`)

| Chave | Label implícito | Painel Mestre | UI admin dedicada |
|-------|-----------------|---------------|-------------------|
| `subscription.manage` | Assinaturas e planos | Assinaturas + Planos | Lista only |
| `payment.view` | Ver pagamentos | — | **Sem tela** |
| `payment.refund` | Reembolsos | — | **Sem tela** |
| `seller.manage` | Vendedores | Vendedores | Lista only |
| `affiliate.manage` | Afiliados | Afiliados | Lista only |
| `coupon.manage` | Cupons | Cupons | Lista only |
| `partnership.manage` | Parceiros | Parceiros | Lista only |
| `ad.manage` | Propagandas | Propagandas | Lista only |
| `dashboard.view` | Dashboard mestre | Dashboard + entrada Painel | Sim |
| `user.manage` | Usuários | Usuários | Lista only |
| `audit.read` | Auditoria | Auditoria | Sim |
| `platform.settings` | Config RBAC | Configurações | Parcial |
| `content.read` | Conteúdo (aluno) | — | Todo aluno autenticado |
| `notification.broadcast` | Broadcast | — | **Sem UI** (global_messages legado) |

### 9.2 Papéis comerciais (`RolePermissionMatrix`)

| Papel | Permissões monetização relevantes |
|-------|-----------------------------------|
| `masterAdmin` / `admin` | Todas comerciais + dashboard |
| `finance` | `payment.view`, `payment.refund`, `audit.read`, `dashboard.view` |
| `seller` | `dashboard.view`, `content.read` |
| `affiliate` | `dashboard.view`, `content.read` |
| `partner` | `partnership.manage`, `content.read` |
| `support` | `user.manage`, `audit.read`, `admin.panel.access` |
| `user` / `student` | `content.read` only |

**Gap:** Papéis `seller`/`affiliate`/`finance` **não têm telas próprias** — só matriz preparatória.

---

## 10. Menor caminho possível para vender o primeiro plano pago

Objetivo: **primeira receita real** com diff mínimo, sem refatorar todo o app.

### Fase 0 — Pré-requisitos (1–2 dias)

1. `firebase deploy --only firestore:rules,firestore:indexes`
2. Garantir admin operacional (`admins/{uid}` ou `users.isAdmin`)
3. Criar **1 plano** no Firestore `platform_subscription_plans` (via Console ou script):

```json
{
  "name": "Trilha Med Premium",
  "description": "Acesso completo por 30 dias",
  "priceMonthly": 49.90,
  "priceYearly": 499.00,
  "currency": "BRL",
  "featureKeys": ["premium.all"],
  "isActive": true,
  "sortOrder": 1
}
```

### Fase 1 — MVP “manual + PIX” (3–5 dias) — **menor caminho sem gateway**

| Passo | Ação |
|-------|------|
| 1 | Tela aluno **“Assinar”** no Perfil — lista planos (`watchActivePlans`) |
| 2 | Botão “Solicitar assinatura” → cria doc em `platform_payments` status `pending` + WhatsApp/e-mail admin |
| 3 | Admin confirma PIX → **Function ou script admin** cria `platform_subscriptions` `active` + `platform_payments` `succeeded` |
| 4 | **Paywall mínimo:** um ponto de gate (ex.: botão Simulado ou OSCE) chama `watchActiveForUser` — se null, mostra upsell |
| 5 | Rules: **remover** `create` em `platform_subscriptions` para client (só Admin SDK) |

**Prós:** Zero taxa gateway, valida disposição a pagar. **Contras:** Manual, não escala.

### Fase 2 — Mercado Pago Checkout Pro (1–2 semanas) — **menor caminho automatizado BR**

| Passo | Ação |
|-------|------|
| 1 | Firebase Function `createMercadoPagoPreference(planId, userId)` |
| 2 | Flutter abre URL checkout (`url_launcher`) |
| 3 | Webhook MP → Function atualiza `platform_payments` + cria `platform_subscriptions` |
| 4 | Mesmo paywall Fase 1 |
| 5 | Adicionar `mercadoPagoItemId` no plano |

### Fase 3 — Endurecer (paralelo / depois)

- Restringir rules `flashcards`/`questoes` por entitlement ou assinatura
- CRUD planos no Painel Mestre
- Cupom no checkout
- `platform_entitlements` para features granulares

### Caminho **não** recomendado como primeiro passo

- Stripe primeiro (Brasil)
- CRUD completo de todos módulos comerciais antes da primeira venda
- Paywall em todo conteúdo antes de validar preço/plano

---

## Matriz resumo — pronto vs falta

| Capacidade | Pronto | Parcial | Falta |
|------------|--------|---------|-------|
| Schema Firestore comercial | ✓ | | |
| Repositorios Dart | ✓ | | |
| Rules + índices (repo) | ✓ | Deploy | |
| Painel listagem admin | ✓ | CRUD | |
| RBAC permissões | ✓ | UI finance/refund | |
| Checkout aluno | | | ✓ |
| Webhooks / Functions | | | ✓ |
| Paywall | | | ✓ |
| Mercado Pago | | enum | ✓ integração |
| Stripe | | enum | ✓ integração |
| Entitlements | | rules | ✓ código |
| Ads no app | | repo | ✓ UI |
| Afiliados tracking | | modelo | ✓ fluxo |

---

## Referências de código

| Tema | Caminho |
|------|---------|
| Registry | `lib/application/platform/platform_registry.dart` |
| Repositórios | `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart` |
| Modelos | `lib/domain/platform/models/` |
| Painel | `lib/screens/master_admin/` |
| Permissões | `lib/core/permissions/app_permission.dart` |
| Rules | `firestore.rules` L394–494 |
| Índices | `firestore.indexes.json` |
| Dependências | `pubspec.yaml` (sem SDK pagamento) |

---

**Fim da auditoria de monetização — nenhuma alteração de código foi aplicada.**
