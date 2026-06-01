# Relatório Prévio — Integração Mercado Pago

**Data:** maio/2026  
**Projeto:** revalida-cards  
**Escopo:** Checkout Pro + Cloud Functions + webhook + assinaturas automáticas  
**Restrição:** não alterar fluxos de estudo; compatível com MVP comercial existente

---

## 1. Estado atual (baseline)

| Componente | Status |
|------------|--------|
| Modelos `Subscription`, `Payment`, `PlatformEntitlement` | ✅ Prontos |
| `PaymentProvider.mercadoPago` | ✅ Enum existe |
| `CommercialAccessService` / `CommercialAdminService` | ✅ Manual + paywall opt-in |
| Telas Planos / Minha Assinatura | ✅ Sem botão de pagamento |
| Painel Mestre CRUD comercial | ✅ Sem módulo de pagamentos |
| Cloud Functions | ❌ Pasta `functions/` inexistente |
| Checkout / webhook MP | ❌ Inexistente |
| SDK MP no Flutter | ❌ Não necessário (Checkout Pro via URL) |

---

## 2. Lacunas identificadas (P0)

1. **Server-side checkout** — preferência MP deve ser criada apenas no backend (token secreto).
2. **Webhook** — única fonte confiável para `status: succeeded` e ativação de premium.
3. **Regras Firestore** — hoje usuário pode `create` em `platform_subscriptions` e `platform_payments` (fraude).
4. **Entitlements** — escrita admin-only; webhook usa Admin SDK (correto).
5. **Renovação** — Checkout Pro = pagamento avulso por período (mensal 30d / anual 365d); nova compra estende `currentPeriodEnd`.
6. **Preservação** — `premium_lifetime` e `courtesy_access` não podem ser revogados por webhook de reembolso de outra assinatura.

---

## 3. Arquitetura proposta

```
[PlansPage] → Callable createMercadoPagoCheckout
                    ↓
            [Cloud Function] → MP Preference API
                    ↓
            Firestore platform_payments (pending)
                    ↓
            url_launcher → Checkout Pro MP
                    ↓
            [Webhook MP] → valida pagamento
                    ↓
            platform_payments (succeeded)
            platform_subscriptions (active)
            users/{uid}/platform_entitlements (premium)
                    ↓
            CommercialAccessService.watchAccess → UI atualiza
```

---

## 4. Etapas de implementação

| Etapa | Entrega |
|-------|---------|
| **A** | Relatório prévio (este documento) |
| **B** | `functions/` — checkout callable + webhook + expiração agendada |
| **C** | `firestore.rules` — bloquear create client em subs/payments |
| **D** | Flutter — `MercadoPagoCheckoutService` + botões em `PlansPage` |
| **E** | Painel Mestre — `master_admin_payments_page.dart` |
| **F** | `docs/MERCADO_PAGO_IMPLEMENTATION.md` |

---

## 5. Decisões técnicas

- **Checkout Pro** (não Assinaturas MP nativas) — alinhado ao pedido; renovação = nova compra ou extensão de período no webhook.
- **Períodos:** `billingPeriod: 'monthly' | 'yearly'` → 30 ou 365 dias em `currentPeriodEnd`.
- **Atribuição comercial:** `sellerId`, `affiliateId`, `couponCode` passados no checkout callable.
- **Segurança webhook:** consultar pagamento via API MP (não confiar só no body); idempotência por `providerPaymentId`.
- **Manual admin:** `CommercialAdminService` continua via `isAppAdmin()` — inalterado.

---

## 6. Configuração necessária (operacional)

| Secret / Config | Onde |
|-----------------|------|
| `MERCADOPAGO_ACCESS_TOKEN` | Firebase Functions params / Secret Manager |
| `MERCADOPAGO_WEBHOOK_SECRET` | Opcional — validação x-signature |
| `APP_CHECKOUT_SUCCESS_URL` | Deep link ou URL web pós-pagamento |
| `APP_CHECKOUT_FAILURE_URL` | Idem |
| Webhook URL no painel MP | `https://.../mercadopagoWebhook` |

---

## 7. Riscos e mitigação

| Risco | Mitigação |
|-------|-----------|
| Cliente cria assinatura fake | Rules: create subs/payments só admin |
| Webhook duplicado | Transação Firestore + check status atual |
| Reembolso remove vitalício | Filtrar entitlements por `key == premium` e `subscriptionId` |
| Índice composto | Adicionar `platform_payments: status + paidAt` |

---

## 8. Compatibilidade MVP comercial

- ✅ `CommercialAccessService` — sem alteração de contrato
- ✅ `CommercialAdminService` — grants manuais preservados
- ✅ `PaywallGate` — opt-in, não aplicado em estudo
- ✅ Coleções e paths Firestore — mesmos nomes
- ➕ Novo: `MercadoPagoCheckoutService` em `PlatformRegistry`

---

**Aprovado para implementação em etapas B→F.**
