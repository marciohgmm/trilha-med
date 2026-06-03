# App Check — checklist de enforcement em produção

**Objetivo:** bloquear clientes não registrados (bots, clones, scripts) nas APIs Firebase.

O app Flutter já inicializa App Check em `main.dart` (`AppCheckService`) e as callables sensíveis usam `appCheckCallableOptions()` (`enforceAppCheck: true`). **Isso não substitui** ativar enforcement no Firebase Console.

## Checklist (executar no Console após build release validado)

| Produto | Onde no Console | Ação |
|---------|-----------------|------|
| **Authentication** | Build → App Check → APIs | **Enforce** para Authentication |
| **Cloud Firestore** | idem | **Enforce** para Cloud Firestore |
| **Cloud Functions** | idem | **Enforce** para Cloud Functions (callables) |
| **Cloud Storage** | idem | **Enforce** para Cloud Storage |

### Ordem recomendada

1. Publicar app com tokens de produção (Play Integrity / App Attest / reCAPTCHA web).
2. Monitorar **App Check → Metrics** por 24–48 h (taxa de rejeição).
3. Ativar **Enforce** em **Monitoring** primeiro, depois **Enforce** definitivo por API.
4. Manter `MERCADOPAGO_WEBHOOK` e schedulers **sem** App Check (HTTP externo / triggers internos).

### Desenvolvimento local

- `APP_CHECK_DEBUG=true` ou emulador: provider debug; registrar token no Console.
- **Nunca** usar debug define em `kReleaseMode` — `AppCheckConfig.assertProductionSafe()` falha o build.

### Referências no código

- `lib/core/app_check/app_check_config.dart`
- `lib/services/app_check/app_check_service.dart`
- `functions/src/callableOptions.ts`
- `storage.rules` (comentário no topo)
- `docs/APP_CHECK_IMPLEMENTATION_REPORT.md`

### Pós Dia 1 (auditoria)

Callables `notifyLiveEventUser` e `scheduleLiveEventReminders` exigem auth + host/admin; com App Check **Enforced**, abuso fica limitado ao app registrado.
