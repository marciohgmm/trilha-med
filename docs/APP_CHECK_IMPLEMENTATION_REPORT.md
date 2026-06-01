# Firebase App Check — Relatório de implementação (Etapas B–H)

**Data:** 2026-05-19  
**Pré-relatório:** [APP_CHECK_PRE_REPORT.md](./APP_CHECK_PRE_REPORT.md)

---

## ANTES × DEPOIS

| Área | Antes | Depois |
|------|-------|--------|
| Cliente Flutter | Sem `firebase_app_check` | Play Integrity / App Attest+DeviceCheck / reCAPTCHA (web) |
| Inicialização | Só `Firebase.initializeApp` | `AppCheckService` logo após Firebase |
| Callables sensíveis | Sem `enforceAppCheck` | `appCheckCallableOptions()` em 10 callables |
| Webhook MP | HMAC | **Inalterado** (sem App Check) |
| Storage/Firestore rules | Só `request.auth` | Comentários + compatível com Console Enforced |
| Dev | — | `APP_CHECK_DEBUG` / emulador; bloqueado em `kReleaseMode` |
| Testes | — | Flutter + `functions/test/appCheckEnforcement.test.mjs` |

---

## Etapa B — Flutter

**Arquivos:**
- `lib/core/app_check/app_check_config.dart`
- `lib/services/app_check/app_check_service.dart`
- `lib/main.dart` — `await AppCheckService.instance.initialize()` após Firebase
- `pubspec.yaml` — `firebase_app_check`

**Providers:**
| Plataforma | Produção | Desenvolvimento |
|------------|----------|-----------------|
| Android | `AndroidProvider.playIntegrity` | `AndroidProvider.debug` com `APP_CHECK_DEBUG=true` |
| iOS | `AppleProvider.appAttestWithDeviceCheckFallback` | `AppleProvider.debug` |
| Web | `ReCaptchaEnterpriseProvider` ou `ReCaptchaV3Provider` | Mesmos + token debug no Console |

**Dart-define:**
- `APP_CHECK_DEBUG=true` — debug provider (nunca em release)
- `USE_FIREBASE_EMULATOR=true` — mesmo efeito fora de release
- `RECAPTCHA_ENTERPRISE_SITE_KEY` / `RECAPTCHA_V3_SITE_KEY` — web

**Comportamento:** refresh automático (`setTokenAutoRefreshEnabled(true)`), logs em debug, falha em release se init crítico falhar; em debug sem Console, app continua (não bloqueia estudo).

---

## Etapa C — Cloud Functions

**Helper:** `functions/src/callableOptions.ts`

### Protegidas (`enforceAppCheck: true`)

| Callable | `consumeAppCheckToken` |
|----------|------------------------|
| `createMercadoPagoCheckout` | Sim |
| `reconcileMyMercadoPagoPayments` | Sim |
| `registerFcmToken` | Não |
| `createPushCampaign` | Não |
| `notifyLiveEventBroadcast` | Não |
| `notifyLiveEventUser` | Não |
| `scheduleLiveEventReminders` | Não |
| `deleteMyAccount` | Não |

### Dispensadas (justificativa)

| Função | Motivo |
|--------|--------|
| `mercadopagoWebhook` | Callback externo Mercado Pago; proteção HMAC |
| `reconcileMercadoPagoPaymentsScheduled` | Scheduler interno |
| `expireSubscriptionsScheduled` | Scheduler |
| `purgeAnalyticsEventsScheduled` | Scheduler |
| `syncAnalyticsDauScheduled` | Scheduler |
| `onPushCampaignCreated` | Trigger Firestore |
| `push*Scheduled` | Schedulers FCM |

---

## Etapa D — Storage

- `storage.rules`: documentação App Check; rules de auth/admin **inalteradas** para uploads legítimos.
- Enforcement recomendado no Console após validar tokens em Monitoring.

---

## Etapa E — Firestore

- `firestore.rules`: cabeçalho de compatibilidade App Check.
- Regras de login, premium, OSCE, Live Events **não alteradas** (somente comentário).
- App Check não substitui `request.auth`; complementa na borda Firebase.

---

## Etapa F — Desenvolvimento

- Debug/emulador **somente** com `!kReleaseMode` + dart-define explícito.
- `assertProductionSafe()` lança se `APP_CHECK_DEBUG` ou `USE_FIREBASE_EMULATOR` em release build.

**Exemplo local:**
```bash
flutter run --dart-define=APP_CHECK_DEBUG=true
```

Registrar token de debug no Firebase Console → App Check → Apps.

---

## Etapa G — Testes

| Caso | Implementação | Resultado esperado em produção |
|------|---------------|--------------------------------|
| A) Cliente sem App Check | `enforceAppCheck` nas CF | `failed-precondition` / rejeição |
| B) Cliente válido | App oficial + providers | Normal |
| C) Mercado Pago | `createMercadoPagoCheckout` + token | Checkout OK |
| D) Delete account | `deleteMyAccount` + token | OK |

**Executados (estáticos / unitários):**
- `test/app_check/app_check_config_test.dart`
- `test/app_check/app_check_enforcement_expectations_test.dart`
- `functions/test/appCheckEnforcement.test.mjs`

Testes E2E contra emulador exigem projeto Firebase com providers registrados.

---

## Recursos protegidos?

- **Callables listadas:** sim, após deploy das Functions.
- **Firestore / Storage / Auth:** após habilitar **Enforced** no Console (não automático só com código cliente).

---

## Custo reduzido?

- **Potencial alto** em callables de push e leituras Firestore por scripts — mitigado nas callables imediatamente após deploy.
- Redução plena de leituras FS depende de enforcement Console em Firestore.

---

## Riscos remanescentes

1. Console não configurado (Play Integrity, App Attest, reCAPTCHA) → tokens inválidos em produção.
2. `scheduleLiveEventReminders` / `notifyLiveEventUser` ainda com auth fraca no handler (pré-existente); App Check limita a app registrado.
3. Leitura massiva Firestore ainda possível com app legítimo + conta válida até Enforced no Firestore.
4. Web sem dart-define de reCAPTCHA em release build falha no init (intencional).

---

## Deploy necessário?

1. `flutter pub get` + build release com defines web.
2. `firebase deploy --only functions` (callables com App Check).
3. Firebase Console → App Check: registrar providers + debug tokens.
4. Monitoring → **Enforced** (Functions primeiro, depois Firestore/Storage/Auth).
5. `firebase deploy --only firestore:rules,storage` (somente comentários; opcional).

---

## Impacto em usuários / admins

| Grupo | Impacto |
|-------|---------|
| Usuários app oficial | Nenhuma mudança de UX |
| Web | Exige site key em build de produção |
| Admins | Mesmo app; uploads/callables admin exigem token App Check após enforcement |
| MP webhook | Zero impacto |

**Restrições respeitadas:** sem alteração de UX de estudo, monetização (fluxo), OSCE, flashcards; webhook MP intacto.

---

## Referência rápida de arquivos

```
lib/core/app_check/app_check_config.dart
lib/services/app_check/app_check_service.dart
functions/src/callableOptions.ts
functions/test/appCheckEnforcement.test.mjs
test/app_check/*
docs/APP_CHECK_PRE_REPORT.md
```
