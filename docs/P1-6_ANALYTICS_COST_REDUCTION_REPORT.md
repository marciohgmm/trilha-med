# P1-6 — Analytics Mirror: redução de custo

**Data:** 2026-05-19  
**Pré-auditoria:** `docs/P1-6_ANALYTICS_COST_PRE_REPORT.md`

---

## 1. Resumo executivo

| Item | Status |
|------|--------|
| GA4 inalterado | Sim |
| UX do aluno inalterada | Sim |
| Espelho seletivo (eventos críticos) | Sim |
| Agregação `platform_analytics_daily` | Sim |
| TTL eventos brutos (90 dias) | Sim |
| Dashboard lê agregados | Sim |

---

## 2. Antes × Depois

### 2.1 Espelhamento Firestore

| Categoria | Antes | Depois |
|-----------|-------|--------|
| Feature / estudo | Espelhado | **GA4 only** |
| Navegação (screen_view) | GA4 only | GA4 only |
| Comercial crítico | Espelhado | Espelhado + agregado |
| session_start | Espelhado | Espelhado (1×/dia) + active_users |
| coupon/affiliate/seller | Espelhado | **GA4 only** |
| purchase_pending (webhook) | Espelhado | **Removido** |

### 2.2 Coleções

```
platform_analytics_events/{id}     # raw, expireAt + purge 90d
platform_analytics_daily/{YYYY-MM-DD}
  dau, signups, logins, sessions, paywallViews,
  checkoutStarts, purchases, purchasesCancelled, revenue
  active_users/{uid}               # DAU único
```

### 2.3 Dashboard

| Métrica | Antes | Depois |
|---------|-------|--------|
| Fonte principal | 3000 eventos raw | **~30 docs diários** (getAll) |
| Retenção | 3000 eventos raw | **≤2000** eventos filtrados (sign_up + session_start) |
| Feature usage | Firestore | **GA4** (card informativo) |
| DAU hoje/ontem | Raw session_start | **count(active_users)** |

---

## 3. Writes estimados (1.000 DAU / mês)

| Evento | Antes | Depois |
|--------|-------|--------|
| Feature (~10/sessão × 30d) | ~900.000 | **0** |
| session_start | 30.000 | 30.000 (+ active_users set ≈ 30.000)* |
| login/signup/comercial | ~7.000 | ~7.000 |
| Agregado diário (increment) | 0 | ~7.000 |
| **Total Firestore writes/mês** | **~950.000–1.200.000** | **~74.000** |

\* `active_users` é idempotente (1 doc/user/dia) — write apenas na 1ª sessão do dia.

**Redução de writes:** ~**93–94%**

---

## 4. Armazenamento

| | Antes | Depois |
|---|-------|--------|
| Raw events | Crescimento ilimitado | **Purge 90d** (~225k docs max @1k DAU) |
| Agregados | — | **~365 docs/ano** (permanentes) |
| active_users | — | Purge com doc pai ou retenção alinhada |

Economia de storage: após 90 dias, coleção raw **estabiliza** em vez de crescer ~1M docs/mês.

---

## 5. Leituras do dashboard

| Operação | Antes | Depois |
|----------|-------|--------|
| Load snapshot | 1 query 3000 docs | **getAll ~30 daily docs** + count×2 + retention ≤2000 |
| Reads típicas | **~3000** | **~35–50** |

**Redução:** ~**98%** nas leituras do painel.

---

## 6. Economia mensal estimada

Firestore (writes $0.18/100k, reads $0.06/100k, storage $0.18/GB):

| Item | Antes | Depois | Economia |
|------|-------|--------|----------|
| Writes (~1M) | ~$1.80 | ~$0.13 | **~$1.67** |
| Dashboard reads (100 loads) | ~$0.18 | ~$0.003 | ~$0.18 |
| Storage (GB crescente) | crescente | ~flat | variável |

Para escala (10k DAU): economia writes **~$15–20/mês** + storage evitado.

---

## 7. Compatibilidade GA4 / monetização

- **GA4:** todos os eventos continuam sendo enviados.
- **Funis comerciais no painel:** mantidos via agregados.
- **Premium / entitlements:** futuro gate pode usar agregados por plano sem raw mirror.
- **BigQuery export GA4:** recomendado para análise de produto profunda.

---

## 8. Cloud Functions

| Function | Schedule | Função |
|----------|----------|--------|
| `purgeAnalyticsEventsScheduled` | 04:00 BRT | Delete raw > 90 dias |
| `syncAnalyticsDauScheduled` | 04:30 BRT | Atualiza campo `dau` |

Webhook MP: espelha apenas `purchase_approved` / `purchase_cancelled`.

---

## 9. Arquivos alterados

| Arquivo | Mudança |
|---------|---------|
| `lib/core/analytics/analytics_mirror_policy.dart` | **Novo** |
| `lib/core/analytics/analytics_daily_record.dart` | **Novo** |
| `lib/services/analytics/app_analytics_service.dart` | Espelho seletivo + agregado |
| `lib/application/analytics/analytics_dashboard_service.dart` | Lê agregados |
| `functions/src/analyticsService.ts` | Policy + daily increment |
| `functions/src/analyticsScheduled.ts` | **Novo** purge + DAU |
| `functions/src/webhook.ts` | Remove mirror pending |
| `firestore.rules` | daily + active_users |
| `test/core/analytics/analytics_mirror_policy_test.dart` | **Novo** |

---

## 10. Checklist de deploy

- [ ] `flutter test test/core/analytics/`
- [ ] `cd functions && npm run build && npm test`
- [ ] Deploy rules + indexes: `firebase deploy --only firestore:rules,firestore:indexes`
- [ ] Deploy functions: `purgeAnalyticsEventsScheduled`, `syncAnalyticsDauScheduled`
- [ ] Deploy app Flutter
- [ ] Validar Painel Mestre → Analytics (métricas comerciais + DAU)
- [ ] Confirmar GA4 recebendo eventos de feature (DebugView)
- [ ] Após 24h: verificar docs em `platform_analytics_daily`
- [ ] Opcional: configurar TTL Firestore no campo `expireAt` (backup ao purge CF)

---

## 11. Nota sobre session_start

Incluído no espelho por ser **1×/dia/dispositivo** (SharedPreferences) — necessário para retenção D1/D7/D30. Volume ~30k/mês vs ~900k de feature events — impacto marginal vs benefício administrativo.
