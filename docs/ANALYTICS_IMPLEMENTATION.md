# Firebase Analytics — implementação

## Visão geral

O app envia eventos para **Firebase Analytics (GA4)** e espelha uma cópia em Firestore (`platform_analytics_events`) para o **Painel Mestre → Analytics**, com métricas de crescimento, conversão e retenção D1/D7/D30.

## Arquitetura

| Camada | Arquivo | Função |
|--------|---------|--------|
| Constantes | `lib/core/analytics/analytics_events.dart` | Nomes e parâmetros padronizados |
| Serviço | `lib/services/analytics/app_analytics_service.dart` | FA + espelho Firestore + sessão diária |
| Dashboard | `lib/application/analytics/analytics_dashboard_service.dart` | Agregação admin (30 dias) |
| UI admin | `lib/screens/master_admin/modules/master_admin_analytics_page.dart` | Cards e tabelas |
| Instrumentação | Telas de estudo, comercial, auth | `AnalyticsFeatures` / mixin |

## Eventos rastreados

### Auth e retenção
- `login`, `sign_up`
- `session_start` — máx. 1×/dia/dispositivo (base para DAU e retenção)

### Produto
- `flashcard_study_start`, `questions_study_start`
- `simulado_start`, `simulado_complete`
- `osce_lobby_open`, `osce_station_start`
- `practical_phase_open`, `live_event_join`

### Comercial
- `paywall_view`, `plans_view`
- `checkout_start`, `purchase_approved`, `purchase_cancelled`, `purchase_pending`
- `coupon_applied`, `affiliate_attributed`, `seller_attributed`

### Servidor (webhook MP)
- `purchase_*` também gravados via Cloud Function (`functions/src/analyticsService.ts`)

## Retenção D1/D7/D30

Calculada no dashboard a partir de:
1. Cohort: usuários com `sign_up` nos últimos 30 dias
2. Retorno: `session_start` no dia N após o cadastro

Para cohorts maiores, exporte para **BigQuery** (link GA4) ou agende Cloud Function de agregação.

## Permissões

- RBAC: `analytics.view` — founder, admin, finance
- Firestore: leitura admin; criação apenas pelo próprio `userId`

## Deploy

1. `flutter pub get`
2. Habilitar Analytics no projeto Firebase Console
3. `firebase deploy --only firestore:rules,firestore:indexes`
4. `cd functions && npm run build && firebase deploy --only functions`

## Debug

Em `kDebugMode`, a coleta FA fica desabilitada (`setAnalyticsCollectionEnabled(false)`), mas o espelho Firestore continua ativo para testes do dashboard admin.

## Próximos passos (opcional)

- User properties: `plan_tier`, `signup_cohort`
- Funis GA4: paywall → plans → checkout → purchase
- Agregação diária em `platform_analytics_daily` via scheduled function
