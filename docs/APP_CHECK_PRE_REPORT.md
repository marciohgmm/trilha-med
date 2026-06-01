# Firebase App Check — Relatório pré-implementação (Etapa A)

**Data:** 2026-05-19  
**Escopo:** Auditoria somente leitura — sem alteração de código nesta etapa (documento gerado na mesma entrega das etapas B–H).

---

## 1. Resumo executivo

O app Flutter usa **Firebase Auth**, **Firestore**, **Storage**, **FCM** e **Cloud Functions** (região `southamerica-east1`). **Não havia** `firebase_app_check` no cliente nem `enforceAppCheck` nas callables. O webhook Mercado Pago já possui validação HMAC (`x-signature`). Firestore e Storage dependem de **regras por `request.auth`**, não de App Check.

**Risco principal:** clientes modificados podem chamar callables autenticadas, fazer leituras/escritas permitidas pelas rules e uploads Storage autorizados por auth/admin — gerando **custo** (Firestore reads/writes, Functions invocations, Storage egress) e **abuso** (push, checkout, reconciliação).

---

## 2. Inventário Cloud Functions

| Função | Tipo | App Check (antes) | Observação |
|--------|------|-------------------|------------|
| `createMercadoPagoCheckout` | Callable | ❌ | Monetização — alto custo/risco |
| `reconcileMyMercadoPagoPayments` | Callable | ❌ | Reconciliação por usuário |
| `registerFcmToken` | Callable | ❌ | Escrita em `users`, `fcm_users` |
| `createPushCampaign` | Callable | ❌ | Admin — fila de campanhas |
| `notifyLiveEventBroadcast` | Callable | ❌ | Push em massa (host/admin) |
| `notifyLiveEventUser` | Callable | ❌ | Push direcionado |
| `scheduleLiveEventReminders` | Callable | ❌ | Marca evento (auth fraca no handler) |
| `deleteMyAccount` | Callable | ❌ | LGPD — destrutivo |
| `mercadopagoWebhook` | HTTP `onRequest` | N/A | Servidor MP — **não** usar App Check |
| `reconcileMercadoPagoPaymentsScheduled` | Scheduler | N/A | Backend only |
| `expireSubscriptionsScheduled` | Scheduler | N/A | Backend only |
| `purgeAnalyticsEventsScheduled` | Scheduler | N/A | Backend only |
| `syncAnalyticsDauScheduled` | Scheduler | N/A | Backend only |
| `onPushCampaignCreated` | Firestore trigger | N/A | Backend only |
| `push*Scheduled` (várias) | Scheduler | N/A | Backend only |

### 2.1 Endpoints HTTP públicos

- **`mercadopagoWebhook`**: público por design; protegido por `MERCADOPAGO_WEBHOOK_SECRET` / assinatura. App Check **incompatível** com callbacks externos.

### 2.2 Callables chamadas pelo app (Flutter)

| Callable | Arquivo cliente |
|----------|-----------------|
| `createMercadoPagoCheckout` | `lib/application/commercial/mercado_pago_checkout_service.dart` |
| `reconcileMyMercadoPagoPayments` | idem |
| `registerFcmToken` | `lib/services/push/fcm_service.dart` |
| `createPushCampaign` | `lib/application/push/push_campaign_admin_service.dart` |
| `notifyLiveEventBroadcast` | `lib/services/live_event_notification_service.dart` |
| `notifyLiveEventUser` | idem |
| `scheduleLiveEventReminders` | idem |
| `deleteMyAccount` | `lib/screens/legal/delete_account_page.dart` |

---

## 3. Firebase Auth

| Aspecto | Estado (antes) |
|---------|----------------|
| Proteção App Check | ❌ Não configurado no cliente |
| Abuso | Scripts com API key + credenciais roubadas |
| Custo | Auth baixo; vetor para outros serviços |
| Enforcement | Recomendado **Monitoring → Enforced** no Console após rollout |

Login/email verification **não** deve quebrar: App Check complementa Auth; usuários legítimos com app oficial enviam token.

---

## 4. Firestore

### 4.1 Coleções sensíveis (custo / privacidade / privilégio)

| Coleção / padrão | Risco sem App Check |
|------------------|---------------------|
| `users/{uid}` | Leitura/escrita de perfil, `fcmTokens`, XP |
| `admins/{uid}` | Escalada bloqueada por rules (P0-A) |
| `payments`, assinaturas | Leitura limitada por rules; escrita server-side preferencial |
| `live_events`, participantes | OSCE/Live — coordenação, recompensas |
| `osce_*` / salas | Estado de simulação |
| `push_campaigns` | Criação via callable admin |
| `flashcards`, `questoes`, hierarquia | Conteúdo — leitura massiva = custo |
| `practical_phase_*` | Conteúdo premium/admin |
| `platform_audit_logs` | Append server/admin |
| `legal_acceptances` | Append-only LGPD |

### 4.2 Rules

- Baseadas em `request.auth`, `isAppAdmin()`, ownership.
- **Sem** `request.app` nas rules (antes) — compatível com rollout gradual.
- Enforcement App Check no **Console** não altera sintaxe das rules; clientes sem token falham na camada Firebase antes das rules (modo Enforced).

---

## 5. Firebase Storage

| Path | Read | Write | Abuso |
|------|------|-------|-------|
| `imagenscard/**` | Público | Admin | Upload spam se credencial admin vazada |
| `flashcards/**` | Auth | Admin | Idem |
| `osce_cases/{id}/**` | Auth | OSCE editor | Uploads até 10 MB |
| `practical_phase/{modelId}/**` | Auth | App admin | Idem |

Rules **não** validavam App Check token (padrão Firebase). Abuso: cliente modificado com sessão admin.

---

## 6. FCM

- Registro de token via callable `registerFcmToken` (sem App Check antes).
- Envio massivo: callables Live + `createPushCampaign` + schedulers backend.
- **Maior abuso:** callables de push sem App Check + token FCM válido obtido por script.

---

## 7. Mercado Pago

| Fluxo | Proteção atual | App Check |
|-------|----------------|-----------|
| Checkout app → `createMercadoPagoCheckout` | Auth Firebase | ✅ Callable `enforceAppCheck` |
| Pós-checkout → `reconcileMyMercadoPagoPayments` | Auth | ✅ Callable |
| IPN → `mercadopagoWebhook` | HMAC assinatura | ❌ Manter sem App Check |
| Reconciliação agendada | Scheduler + secrets | N/A |

---

## 8. Rotas críticas (app)

| Fluxo | Serviços |
|-------|----------|
| Login / registro | Auth + Firestore `users` |
| Estudo (flashcards, questões) | Firestore read-heavy |
| Premium / checkout | Callables MP |
| OSCE | Firestore + Storage `osce_cases` |
| Live Events | Firestore + callables push |
| Admin | Firestore + Storage writes + push admin |
| LGPD delete | `deleteMyAccount` |

---

## 9. Matriz: sem proteção / abuso / custo / enforcement

| Recurso | Sem App Check (antes) | Pode sofrer abuso? | Pode gerar custo? | Precisa enforcement? |
|---------|------------------------|--------------------|-------------------|----------------------|
| Callables MP + delete | Sim | Alta | Média | **Sim** (callable) |
| Callables push/FCM | Sim | Alta | Alta (FCM + FS) | **Sim** |
| Firestore leitura conteúdo | Sim | Média | **Alta** | Console (fase 2) |
| Storage upload admin | Sim | Média | Média | Console (fase 2) |
| Auth sign-in | Sim | Média | Baixa | Console (opcional) |
| Webhook MP | HMAC | Baixa (se secret OK) | Baixa | **Não** |
| Schedulers / triggers | N/A | Baixa | Média | N/A |

---

## 10. Recomendações (implementadas nas etapas B–H)

1. **Flutter:** Play Integrity, App Attest + Device Check fallback, reCAPTCHA Enterprise (web), debug só com `--dart-define=APP_CHECK_DEBUG=true`.
2. **Functions:** `enforceAppCheck: true` nas 8 callables listadas + avaliação das 2 callables Live auxiliares.
3. **Console:** Monitoring → Enforced para Functions, depois Firestore/Storage/Auth.
4. **Webhook MP:** manter sem App Check; não alterar fluxo de pagamento.

---

## 11. Referências no repositório

- `functions/src/index.ts` — exports
- `firestore.rules` — modelo de autorização
- `storage.rules` — paths de upload
- `lib/main.dart` — ponto de inicialização Firebase
