# Integração Mercado Pago — Implementação

**Projeto:** revalida-cards  
**Modalidade:** Checkout Pro (pagamento avulso mensal/anual)  
**Relatório prévio:** [MERCADO_PAGO_PRE_AUDIT.md](./MERCADO_PAGO_PRE_AUDIT.md)

---

## 1. Visão geral

```
PlansPage → createMercadoPagoCheckout (Callable)
         → platform_payments (pending)
         → url_launcher → Checkout Pro MP
         → mercadopagoWebhook
         → platform_payments (succeeded)
         → platform_subscriptions (active)
         → users/{uid}/platform_entitlements (premium)
         → CommercialAccessService → Minha Assinatura
```

**Compatível com MVP comercial:** grants manuais (`CommercialAdminService`), paywall opt-in, mesmas coleções Firestore.

---

## 2. Cloud Functions

Pasta: `functions/`

| Função | Tipo | Descrição |
|--------|------|-----------|
| `createMercadoPagoCheckout` | Callable (v2) | Cria preferência MP + doc `pending` |
| `mercadopagoWebhook` | HTTP (v2) | IPN/webhook — valida pagamento via API MP |
| `expireSubscriptionsScheduled` | Scheduler | Expira assinaturas vencidas (03:00 BRT) |

**Região:** `southamerica-east1`

### Secrets / params

```bash
firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN
firebase functions:params:set MERCADOPAGO_WEBHOOK_URL="https://southamerica-east1-revalida-cards.cloudfunctions.net/mercadopagoWebhook"
firebase functions:params:set APP_CHECKOUT_SUCCESS_URL="https://revalida-cards.web.app/checkout/success"
firebase functions:params:set APP_CHECKOUT_FAILURE_URL="https://revalida-cards.web.app/checkout/failure"
firebase functions:params:set APP_CHECKOUT_PENDING_URL="https://revalida-cards.web.app/checkout/pending"
```

Sandbox: `MERCADOPAGO_SANDBOX=true` no ambiente da function (usa `sandbox_init_point`).

### Deploy

```bash
cd functions && npm install && npm run build
firebase deploy --only functions,firestore:rules,firestore:indexes
```

---

## 3. Flutter

| Arquivo | Função |
|---------|--------|
| `lib/application/commercial/mercado_pago_checkout_service.dart` | Callable + `url_launcher` |
| `lib/application/platform/platform_registry.dart` | `mercadoPagoCheckout` |
| `lib/screens/commercial/plans_page.dart` | Botões mensal/anual + cupom |
| `lib/screens/commercial/checkout_return_page.dart` | Página pós-retorno (deep link) |

**Dependência:** `cloud_functions: ^6.0.6`

### Exemplo

```dart
await PlatformRegistry.instance.mercadoPagoCheckout.startCheckout(
  planId: 'premium_plan_id',
  billingPeriod: 'monthly', // ou 'yearly'
  couponCode: 'PROMO10',
);
```

---

## 4. Ciclo de assinatura

| Evento MP | Ação |
|-----------|------|
| `approved` | Ativa/estende assinatura + entitlement `premium` |
| `pending` / `in_process` | Payment `processing` |
| `cancelled` / `rejected` | Payment `canceled`, assinatura cancelada |
| `refunded` / `charged_back` | Payment `refunded`, revoga `premium` da assinatura MP |

**Períodos:** mensal = 30 dias, anual = 365 dias (`currentPeriodEnd`).  
**Renovação:** nova compra **estende** `currentPeriodEnd` se ainda ativa.

**Preservados em reembolso/expiração:**
- `premium_lifetime`
- `courtesy_access`
- `beta_tester`

---

## 5. Segurança (Firestore rules)

```javascript
// platform_subscriptions — create/update/delete: isAppAdmin() apenas
// platform_payments — create/update/delete: isAppAdmin() apenas
// users/{uid}/platform_entitlements — write: isAppAdmin() (Functions usam Admin SDK)
```

Cliente **não** pode criar assinatura ativa nem marcar pagamento como `succeeded`.  
Apenas webhook (Admin SDK) ativa premium após pagamento aprovado.

Grants manuais continuam via admin autenticado (`CommercialAdminService`).

---

## 6. Painel Mestre

| Módulo | Conteúdo |
|--------|----------|
| **Pagamentos** | Abas: Todos, Aprovados, Pendentes, Reembolsos |
| **Assinaturas** | Lista + concessão manual (inalterada) |
| **Dashboard** | Receita mensal, conversões (já existente) |

Permissão pagamentos: `payment.view`

---

## 7. Coleção `platform_payments` (checkout)

Campos escritos pela Function:

| Campo | Valor inicial |
|-------|---------------|
| `userId` | UID autenticado |
| `planId` | Plano escolhido |
| `amount` | Preço mensal/anual |
| `status` | `pending` → webhook atualiza |
| `provider` | `mercado_pago` |
| `providerPaymentId` | preferenceId / payment id MP |
| `metadata.billingPeriod` | `monthly` \| `yearly` |
| `metadata.checkoutUrl` | URL Checkout Pro |

---

## 8. Configuração Mercado Pago (painel)

1. Criar aplicação em [Mercado Pago Developers](https://www.mercadopago.com.br/developers)
2. Obter **Access Token** de produção/teste
3. Configurar **Webhooks** → URL da function `mercadopagoWebhook`
4. Eventos: `payment` (created/updated)

---

## 9. Índices Firestore

Adicionados em `firestore.indexes.json`:

- `platform_payments`: `status` + `paidAt`
- `platform_subscriptions`: `status` + `updatedAt`
- `platform_subscriptions`: `status` + `currentPeriodEnd` (job de expiração)

---

## 10. O que não mudou (estudo)

- Flashcards, questões, OSCE, cronograma — **sem paywall**
- `PaywallGate` — opt-in, não aplicado em telas legadas
- Fluxo manual do Painel Mestre — preservado

---

## 11. Teste end-to-end

1. Configurar token MP (sandbox) nos secrets
2. Deploy functions + rules
3. Criar plano Premium com `priceMonthly` / `priceYearly` > 0
4. Aluno logado → Planos → Assinar mensal
5. Pagar no Checkout Pro (cartão teste MP)
6. Verificar webhook nos logs: `firebase functions:log`
7. Perfil → Minha Assinatura → status **Ativo**
8. Painel Mestre → Pagamentos → aba Aprovados

### Cartões teste MP

Consulte documentação MP para números de cartão de sandbox.

---

## 12. Próximos passos (opcional)

- Assinaturas recorrentes nativas MP (PreApproval) em vez de Checkout Pro avulso
- Deep links mobile para `checkout_return_page`
- Cloud Function para conciliação diária de pagamentos pendentes
- Cupom com desconto aplicado no valor da preferência (hoje só rastreia código)

---

*Implementação alinhada ao MVP comercial — maio/2026.*
