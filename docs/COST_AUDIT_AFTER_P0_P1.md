# Auditoria de custo — Após correções P0 / P1

**Data:** 2026-05-19  
**Escopo:** Estimativa mensal comparativa (antes × depois) para Firestore, Cloud Functions, Storage, Analytics (espelho Firestore + GA4), FCM.  
**Base:** Relatórios `P0-1`, `P0-2`, `P0-3`, `P0-6`, `P1-6`, `FINAL_AUDIT_POST_IMPLEMENTATION.md`.

> **Nota:** Valores em **USD (US$)** no tier Blaze (região típica). GA4 e FCM no Firebase **não têm cobrança por volume** no uso normal; Analytics abaixo refere-se ao **espelho Firestore** + agregados. Números são **ordem de grandeza** para planejamento — validar com **Firebase Usage**, **Cloud Logging** (`[push-metrics]`) e **BigQuery export** após 7–14 dias em produção.

---

## 1. Resumo executivo

| Escala (MAU) | Custo mensal **antes** (est.) | Custo mensal **depois** (est.) | Economia |
|--------------|-------------------------------|--------------------------------|----------|
| 100 | ~US$ 8 | ~US$ 2 | **~75%** |
| 500 | ~US$ 38 | ~US$ 8 | **~79%** |
| 1.000 | ~US$ 72 | ~US$ 14 | **~81%** |
| 5.000 | ~US$ 340 | ~US$ 62 | **~82%** |
| 10.000 | ~US$ 670 | ~US$ 120 | **~82%** |

**Maiores ganhos:** Firestore **reads** (Home, Questões, Cronograma, proteção de listagem) e **writes/storage** do espelho Analytics (P1-6).  
**UX do aluno e GA4:** inalterados.

---

## 2. Correções P0 / P1 consideradas

| ID | Tema | Efeito principal no custo |
|----|------|---------------------------|
| **P0-1** | Home — `flashcards_materia_stats` | Leituras Home: **O(N) → O(M)**; fim de reentrega global a todos os alunos |
| **P0-2** | Live Events — público FCM + cache | Reads resolução push live: **~11k → ~51** por evento (participantes) |
| **P0-3** | Proteção conteúdo — rules + catálogos questões | Listagem questões/simulado: **~Q → ~M**; bloqueio de scrape `get()` completo |
| **P0-6** | Cronograma — `flashcards_subtema_catalog` | Sync/criar cronograma: **~N → ~S** reads |
| **P1-6** | Analytics mirror seletivo + `platform_analytics_daily` + purge 90d | Writes espelho: **~1,2M → ~74k** / 1k DAU; dashboard **~3k → ~50** reads/load |

**Fora desta rodada (custo residual):** `getTodasQuestoes()` (admin), `admin_materias` com `flashcards.snapshots()`, lobby OSCE, `platform_audit_logs` create aberto, retenção admin (≤2k eventos), push `platform_public` (~2,2k reads).

---

## 3. Premissas de modelagem

### 3.1 Plataforma (fixo, não escala com usuários)

| Parâmetro | Valor |
|-----------|-------|
| Flashcards **N** | 10.000 |
| Questões **Q** | 3.000 |
| Matérias **M** | 30 |
| Subtemas **S** | 250 |
| Imagens / mídia (Storage) | ~15 GB catálogo |
| Eventos Live / mês (push lembrete + broadcast) | 30 |

### 3.2 Comportamento por MAU / mês

| Atividade | Frequência / MAU |
|-----------|------------------|
| Sessões no app | 20 |
| Aberturas Home | 5 |
| Hub Questões (lista matérias) | 3 |
| Aberturas Cronograma | 2 (**50%** dos MAU usam cronograma → fator 0,5) |
| Sessões de estudo (flashcard/questão) | 15 × ~50 reads escopados |
| Progresso / perfil (streams) | ~1.000 reads |
| **DAU** (para analytics) | **35% × MAU** |

### 3.3 Preços Firebase (referência)

| Recurso | Preço (aprox.) |
|---------|----------------|
| Firestore reads | US$ 0,06 / 100k |
| Firestore writes | US$ 0,18 / 100k |
| Firestore storage | US$ 0,18 / GB-mês |
| Cloud Functions invocações | US$ 0,40 / 1M (+ compute / rede) |
| Storage (armazenamento) | US$ 0,026 / GB-mês |
| Storage download | US$ 0,12 / GB (após free tier diário) |
| **GA4** | **US$ 0** (plano padrão) |
| **FCM** | **US$ 0** (sem cobrança Firebase por envio) |

---

## 4. Firestore — volumes e custo

### 4.1 Reads / MAU / mês (componentes)

| Componente | Antes (reads/MAU) | Depois (reads/MAU) | Δ |
|------------|-------------------|---------------------|---|
| Home (matérias) | 5 × **N** = 50.000 | 5 × (**M**+200) ≈ 1.150 | **−98%** |
| Questões (hub matérias) | 3 × **Q** = 9.000 | 3 × **M** = 90 | **−99%** |
| Cronograma (catálogo) | 2 × 0,5 × **N** = 10.000 | 2 × 0,5 × **S** = 250 | **−98%** |
| Estudo + progresso + misc. | ~2.150 | ~2.150 | ≈0 |
| **Subtotal / MAU** | **~71.150** | **~3.640** | **~−95%** |

**Reads fixos plataforma / mês (não por MAU):**

| Item | Antes | Depois |
|------|-------|--------|
| Resolução público Live (30 eventos × ~50 inscritos) | ~330.000 | ~1.500 |
| Painel Analytics (100 cargas × reads/carga) | ~300.000 | ~5.000 |
| Admin / OSCE / seeds (ordem) | ~50.000 | ~50.000 |

### 4.2 Writes / MAU / mês (espelho + uso normal)

| Componente | Antes | Depois | Notas |
|------------|-------|--------|-------|
| Analytics espelho (por DAU) | 0,35×MAU × **1.200** | 0,35×MAU × **74** | P1-6; GA4 continua 100% |
| Progresso, tokens, live, CRUD | ~80 × MAU | ~80 × MAU | Inalterado |
| Agregado `platform_analytics_daily` | 0 | ~0,35×MAU × 7 | Incrementos diários |

### 4.3 Tabela consolidada Firestore (US$/mês)

| MAU | Reads/mês (antes → depois) | Custo reads | Writes/mês (antes → depois) | Custo writes | Storage Firestore* | **Total Firestore** |
|-----|----------------------------|-------------|-----------------------------|--------------|-------------------|---------------------|
| **100** | 7,5M → 0,42M | $4,50 → $0,25 | 55k → 16k | $0,10 → $0,03 | $0,20 → $0,10 | **$4,80 → $0,38** |
| **500** | 36M → 1,9M | $21,6 → $1,14 | 270k → 78k | $0,49 → $0,14 | $0,50 → $0,15 | **$22,6 → $1,43** |
| **1.000** | 71M → 3,7M | $42,6 → $2,22 | 520k → 150k | $0,94 → $0,27 | $1,00 → $0,20 | **$44,5 → $2,69** |
| **5.000** | 356M → 18,5M | $213 → $11,1 | 2,6M → 750k | $4,68 → $1,35 | $3,00 → $0,40 | **$221 → $12,9** |
| **10.000** | 712M → 37M | $427 → $22,2 | 5,2M → 1,5M | $9,36 → $2,70 | $5,00 → $0,60 | **$441 → $25,5** |

\* Storage Firestore: antes = crescimento ~1M docs analytics/mês @ 1k DAU (~1–5 GB/ano); depois = teto ~225k docs raw (90d) + 365 daily + `active_users` — **platô** após 3 meses.

**Economia Firestore (1.000 MAU):** ~**US$ 42/mês → ~US$ 3/mês** só em reads+writes; storage evita **dezenas de GB** em 12 meses.

---

## 5. Analytics (espelho Firestore + GA4)

| Aspecto | Antes | Depois |
|---------|-------|--------|
| **GA4** | Todos os eventos | **Igual** (sem custo Firebase) |
| Eventos espelhados | Feature + comercial + session (~40 tipos) | **7 críticos** + `session_start` |
| Writes Firestore / 1k DAU | ~950k–1,2M | ~74k |
| Dashboard Painel Mestre | 3.000 docs raw | ~30 daily + count + ≤2k retenção |
| Retenção produto detalhada | Firestore raw | **GA4 / BigQuery** recomendado |
| Purge | Nenhum | CF `purgeAnalyticsEventsScheduled` (90d) |

### 5.1 Custo Analytics (só Firestore) por escala

| MAU | DAU (35%) | Writes espelho/mês antes | Depois | Custo writes antes | Depois |
|-----|-----------|--------------------------|--------|-------------------|--------|
| 100 | 35 | 42k | 2,6k | $0,08 | $0,005 |
| 500 | 175 | 210k | 13k | $0,38 | $0,02 |
| 1.000 | 350 | 420k | 26k | $0,76 | $0,05 |
| 5.000 | 1.750 | 2,1M | 130k | $3,78 | $0,23 |
| 10.000 | 3.500 | 4,2M | 260k | $7,56 | $0,47 |

**Leituras admin Analytics / mês:** ~US$ 0,15 antes → **~US$ 0,003** depois (100 cargas).

---

## 6. FCM (push)

| Item | Antes | Depois |
|------|-------|--------|
| Cobrança Firebase | **US$ 0** | **US$ 0** |
| Live `all` (erro histórico) | Até **5k+** destinatários indevidos / evento | **Participantes + host** ou `active_7d` (máx. 3k) |
| Reads Firestore resolução | ~11k / evento | ~51 / evento (participantes) |
| Risco real | Quota, reputação, suporte | Controlado |

**Custo mensal FCM:** **US$ 0** na fatura Firebase; benefício principal é **operacional** (menos envios indevidos, menos reads de `users`/`fcmUsers`).

---

## 7. Cloud Storage (imagens / mídia)

| Item | Antes | Depois | Escala com MAU |
|------|-------|--------|----------------|
| Armazenamento catálogo | ~15 GB | ~15 GB | Não |
| Download estimado | ~30 MB/MAU/mês | ~30 MB/MAU/mês | **Sim** |
| Regras / paths | Padrão | Padrão | — |

### 7.1 Custo Storage estimado (US$/mês)

| MAU | Armazenamento (~15 GB) | Download (~30 MB × MAU) | **Total Storage** |
|-----|------------------------|-------------------------|-------------------|
| 100 | ~$0,40 | ~$0,36 | **~$0,76** |
| 500 | ~$0,40 | ~$1,80 | **~$2,20** |
| 1.000 | ~$0,40 | ~$3,60 | **~$4,00** |
| 5.000 | ~$0,40 | ~$18 | **~$18** |
| 10.000 | ~$0,40 | ~$36 | **~$36** |

P0/P1 **não alteram** Storage de forma relevante (uploads admin iguais). Gargalo futuro: **egress** de imagens em flashcards/OSCE com MAU alto.

---

## 8. Cloud Functions

| Função / grupo | Custo driver | Impacto P0/P1 |
|----------------|--------------|---------------|
| `pushLiveEventsScheduled`, `notifyLiveEventBroadcast` | Invocações + reads (via cache) | **P0-2** — menos reads |
| `purgeAnalyticsEventsScheduled`, `syncAnalyticsDauScheduled` | Batch deletes + 1 write/dia | **P1-6** — novo, baixo |
| Webhook pagamento (`purchase_*` mirror) | Poucas invocações | **P1-6** — menos writes mirror |
| Cronograma / flashcard review / simulado scheduled | Invocações fixas | Sem mudança |
| Callable FCM `registerFcmToken` | ~1 write/MAU instalação | Sem mudança |

### 8.1 Custo Functions estimado (US$/mês)

| MAU | Invocações/mês (ordem) | Compute + rede (est.) | **Total Functions** |
|-----|------------------------|------------------------|---------------------|
| 100 | ~3k | ~$0,50 | **~$0,50** |
| 500 | ~8k | ~$1,20 | **~$1,20** |
| 1.000 | ~15k | ~$2,00 | **~$2,00** |
| 5.000 | ~50k | ~$6,00 | **~$6,00** |
| 10.000 | ~100k | ~$12,00 | **~$12,00** |

P0/P1 reduzem **Firestore reads dentro das functions**, não o preço por invocação. Economia Functions: **secundária** (centavos a poucos dólares).

---

## 9. Total mensal estimado (todas as categorias)

| MAU | **Antes** | | | | | **Depois** | | | | | **Economia** |
|-----|-----------|--|--|--|--|------------|--|--|--|--|--------------|
| | Firestore | Functions | Storage | Analytics† | **Σ** | Firestore | Functions | Storage | Analytics† | **Σ** | |
| **100** | $4,8 | $0,5 | $0,8 | $0,1 | **$6,2** | $0,4 | $0,5 | $0,8 | $0,01 | **$1,7** | **−72%** |
| **500** | $22,6 | $1,2 | $2,2 | $0,4 | **$26,4** | $1,4 | $1,2 | $2,2 | $0,02 | **$4,8** | **−82%** |
| **1.000** | $44,5 | $2,0 | $4,0 | $0,8 | **$51,3** | $2,7 | $2,0 | $4,0 | $0,05 | **$8,8** | **−83%** |
| **5.000** | $221 | $6,0 | $18 | $3,8 | **$249** | $13 | $6,0 | $18 | $0,25 | **$37** | **−85%** |
| **10.000** | $441 | $12 | $36 | $7,6 | **$497** | $26 | $12 | $36 | $0,5 | **$75** | **−85%** |

† Analytics = parcela Firestore (writes espelho + reads dashboard); GA4 = $0.

### 9.1 Gráfico comparativo (1.000 MAU)

```
US$/mês (1.000 MAU)
Antes  ████████████████████████████████████████████████████  ~51
Depois █████████                                             ~9
       |---- Firestore ----|-- Storage --|Fn|An|
```

---

## 10. Gargalos restantes (prioridade)

| # | Gargalo | Tipo | Escala | Impacto estimado | Prioridade |
|---|---------|------|--------|------------------|------------|
| 1 | `QuestaoService.getTodasQuestoes()` — stream coleção inteira | Read | Admin | Alto se admin aberto 24/7 | **P1** |
| 2 | `admin_materias_page` — `flashcards.snapshots()` | Read | Admin | O(N) por sessão admin | **P1** |
| 3 | `OsceRoomService` / lobby — queries amplas | Read | OSCE | Médio com muitas salas | **P1** |
| 4 | Retenção Painel Mestre — até **2.000** eventos filtrados | Read | Admin | ~$0,01/carga; 100 cargas = $1/mês | **P2** |
| 5 | `platform_audit_logs` — `create` por qualquer autenticado | Write | Abuso | Spam / custo imprevisível | **P1** |
| 6 | `osce_meta` — write por cliente autenticado | Write/segurança | OSCE | Médio | **P0 segurança** |
| 7 | Live `platform_public` — até **~2.200** reads/evento | Read | Live | Eventos raros com público amplo | **P2** |
| 8 | Subtema com **>500** flashcards (`limit` estudo) | Produto | Conteúdo | UX + reads parciais | **P2** |
| 9 | Storage **egress** imagens | Storage | MAU | Domina custo em **10k MAU** | **P1** |
| 10 | Seed catálogo vazio — rebuild paginado **1×** | Read spike | Migração | O(N) único por coleção | Operacional |
| 11 | Progresso legado sem `materia` — `whereIn` em lotes | Read | Usuários antigos | Baixo, decrescente | **P3** |
| 12 | Simulado “todas matérias” — múltiplas queries | Read | Simulado | Médio vs. scan total | Mitigado P0-3 |

---

## 11. Recomendações pós-P0/P1

1. **Monitorar 14 dias:** Firebase Console → Usage; Cloud Logging → `[push-metrics]`; validar `platform_analytics_daily`.
2. **10k MAU:** planejar **CDN / cache imagens** (Storage egress supera Firestore).
3. **Admin:** paginar `getTodasQuestoes` e substituir `flashcards.snapshots()` em matérias admin.
4. **Analytics produto:** export **GA4 → BigQuery**; reduzir query retenção Firestore para só agregados.
5. **Segurança/custo:** fechar `platform_audit_logs` e `osce_meta` para writes só via Functions.
6. **App Check + rate limit** nas queries escopadas (P0-3) — anti-scrape residual.

---

## 12. Checklist de validação de custo em produção

- [ ] Comparar Firestore **Reads/Writes** semana pré-deploy vs pós-deploy
- [ ] Confirmar coleção `platform_analytics_daily` com 1 doc/dia
- [ ] Confirmar purge: docs `platform_analytics_events` com `expireAt` diminuindo após 90d
- [ ] Log `[push-metrics]`: `userDocReads` < 100 por evento live típico
- [ ] Home: listener apenas em `flashcards_materia_stats` (não `flashcards`)
- [ ] Cronograma: sem `flashcards.get()` no trace (DevTools / debug)
- [ ] Projeção MAU atual vs. tabela §9

---

## 13. Referências

| Documento |
|-----------|
| `docs/P0-1_HOME_FLASHCARDS_AGGREGATION_REPORT.md` |
| `docs/P0-2_LIVE_EVENTS_COST_REDUCTION_REPORT.md` |
| `docs/P0-3_CONTENT_PROTECTION_REPORT.md` |
| `docs/P0-6_CRONOGRAMA_COST_REDUCTION_REPORT.md` |
| `docs/P1-6_ANALYTICS_COST_PRE_REPORT.md` |
| `docs/P1-6_ANALYTICS_COST_REDUCTION_REPORT.md` |
| `docs/FINAL_AUDIT_POST_IMPLEMENTATION.md` |
| `docs/TECHNICAL_AUDIT.md` |

---

*Documento gerado para planejamento financeiro pós-implementação P0/P1. Ajustar premissas (N, Q, sessões/MAU) conforme métricas reais do produto.*
