# Rate Limiting — Relatório pré-implementação (Etapa A)

**Data:** 2026-05-19  
**Escopo:** Auditoria somente leitura (documento base para etapas B–G).

---

## 1. Resumo

O app expõe **8 callables** ao cliente, **1 HTTP** (Mercado Pago) e **Auth nativo** (email/senha no SDK). App Check já protege callables; **não havia** limites por usuário/IP/ação. Firestore `platform_audit_logs` permite `create` por qualquer autenticado (risco de spam de auditoria, fora do escopo direto desta entrega).

---

## 2. Endpoints callable

| Callable | Risco | Custo / abuso | Limite imediato? |
|----------|-------|---------------|------------------|
| `createMercadoPagoCheckout` | **Crítico** | MP API + writes `platform_payments` | **Sim** — 3/h por uid |
| `reconcileMyMercadoPagoPayments` | **Alto** | Reads/updates pagamentos + API MP | **Sim** — 10/h |
| `createPushCampaign` | **Alto** | Fila push + FCM em massa | **Sim** — 20/h |
| `notifyLiveEventBroadcast` | **Alto** | FCM + leituras audiência | **Sim** — 60/h |
| `notifyLiveEventUser` | Médio | FCM direcionado | Recomendado |
| `scheduleLiveEventReminders` | Médio | Write `live_events` | Recomendado |
| `registerFcmToken` | Médio | Writes `users`, `fcm_users` | **Sim** — 60/h |
| `deleteMyAccount` | **Crítico** | Deletes em lote | **Sim** — 2/dia |

## 3. HTTP

| Endpoint | Risco | App Check | Rate limit |
|----------|-------|-----------|------------|
| `mercadopagoWebhook` | Crítico (financeiro) | Não (HMAC) | IP no edge / MP; não alterar fluxo MP |

## 4. Firebase Auth (cliente)

| Operação | Arquivo | Risco | Limite imediato? |
|----------|---------|-------|------------------|
| Login | `login_page.dart` | Alto (credential stuffing) | **Sim** — blocking `beforeSignIn` |
| Cadastro | `register_screen.dart` | Alto | **Sim** — `beforeUserCreated` |
| Reset senha | `login_page.dart`, `perfil_page.dart` | Médio | **Sim** — callable `rateLimitPasswordReset` (pré-check invisível) |

Login/cadastro: **Identity blocking functions**. Reset: callable leve antes do SDK Auth (mesma UI).

## 5. Operações administrativas

| Operação | Canal | Risco |
|----------|-------|-------|
| Push campanha | `createPushCampaign` | Alto |
| Live broadcast | `notifyLiveEventBroadcast` | Alto |
| Painel Mestre / Firestore admin | Rules `isAppAdmin()` | Médio (leituras) |
| Upload Storage admin | Rules | Médio |

## 6. Operações financeiras

- Checkout + reconciliação usuário (callables).
- Webhook + schedulers (backend only).

## 7. Alto custo / spam

| Alvo | Vetor |
|------|--------|
| FCM / push callables | Scripts com token App Check + auth |
| Reconciliação / checkout | Loop pós-login |
| `registerFcmToken` | Spam writes |
| Auth | Força bruta email/senha |
| `platform_audit_logs` create aberto | Spam writes (P1 conhecido) |

## 8. Classificação por área

### Firebase Auth
- Login / signup / reset: **Alto** → blocking + contadores `platform_rate_limits`.

### Cloud Functions
- Callables financeiras e push: **Crítico/Alto** → `enforceRateLimits` + `resource-exhausted`.

### Firestore
- Conteúdo estudo: risco **médio** (leitura em massa); fora de rate limit por endpoint nesta fase.
- `platform_rate_limits`: **Crítico** — somente Admin SDK.

### Push / Live Events
- **Alto** — callables listadas.

### Mercado Pago
- Webhook: HMAC; callable checkout/reconcile: **Crítico**.

### Admin Panel
- Mesmos limites nas callables admin (ex.: 20 campanhas/h).

---

## 9. Perguntas-chave

| Pergunta | Resposta |
|----------|----------|
| Quais geram custo? | Push callables, reconciliação, checkout, FCM token, leituras Live audience |
| Quais permitem abuso? | Push, auth, checkout/reconcile repetidos |
| Limite imediato? | Checkout, reconcile, push admin, broadcast, FCM, delete, auth |

---

## 10. Referências

- `functions/src/index.ts`
- `lib/screens/login_page.dart`, `register_screen.dart`
- `firestore.rules` — `platform_audit_logs`
