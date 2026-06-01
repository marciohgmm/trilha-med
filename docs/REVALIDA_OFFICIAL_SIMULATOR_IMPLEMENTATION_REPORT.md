# Simulado Revalida Oficial — Relatório de Implementação

**Data:** 2026-05-19  
**Escopo:** Módulo completo como produto principal (sem paywall ativo).

---

## ANTES × DEPOIS

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Preset oficial 100q | Opção manual em simulado comum | Modo dedicado **Revalida Oficial** |
| Distribuição por matéria | Shuffle aleatório | **Quota equilibrada** por matéria |
| Distribuição por subtema | Não | Breakdown pós-prova; seleção prioriza subtemas fracos no plano |
| Cronômetro | Elapsed, sem limite | **Countdown 4h** (oficial) |
| Gabarito durante prova | Imediato (`QuestaoCard`) | **Oculto** (`RevalidaExamQuestionCard`) |
| Desempenho parcial | Acertos/erros no header | **Oculto** — só contagem de marcadas |
| Navegação | Anterior/Próxima (swipe bloqueado) | **Livre** (PageView + mapa de questões) |
| Revisão final | Alerta simples | **Grid completo** + confirmação dupla |
| Análise pós-prova | Percentual global | **RevalidaPerformancePage** (matéria, subtema, top 5) |
| Plano de correção | Não | **Estudar minhas fraquezas** (flashcards + questões + subtemas) |
| Histórico evolução | `simulados_historico` genérico | **`revalida_simulations`** + dashboard |
| Entrada na Home | Simulado dentro de Questões | **Card hero** “Simulado Revalida Oficial” |
| Feature flag | Não | `revalida_official_simulator` (sem bloqueio) |
| Simulados comuns | Inalterados | **Inalterados** ✓ |

---

## Fórmulas e lógica

### Seleção equilibrada

\[
quota_i = \lfloor 100 / n \rfloor + \text{resto distribuído}
\]

Por matéria, questões ativas embaralhadas; overflow preenche lacunas.

### Score

\[
score = \frac{acertos}{100} \times 100
\]

(baseado no total de questões da prova, incluindo em branco como erro)

### Evolução

\[
evolução\% = \frac{nota_{atual} - nota_{anterior}}{nota_{anterior}} \times 100
\]

---

## Persistência — `revalida_simulations`

| Campo | Tipo |
|-------|------|
| uid | string |
| startedAt / finishedAt | timestamp |
| durationSeconds | int |
| score | number |
| totalQuestions / correctAnswers / wrongAnswers / unanswered | int |
| subjectBreakdown | array |
| subtopicBreakdown | array |
| questaoIds / respostas | array / map |

**Rules:** titular cria/lê; admin full access.  
**Índice:** `uid` + `finishedAt DESC`.

---

## Leituras Firestore e impacto de custo

| Operação | Leituras estimadas | Quando |
|----------|-------------------|--------|
| Montar prova | **1 × get(`questoes`)** | Início (full collection scan) |
| Entregar prova | **1 write** + até **100 writes** `progresso_questoes` | Entrega |
| Plano fraquezas | ~**5–15 reads** (flashcards + questões por subtema) | Opcional pós-prova |
| Dashboard evolução | **1 query** (limit 20) | Stream |

**Por simulado completo:** ~1 read massiva + 1 write + ~100 writes progresso.  
**Custo incremental:** moderado na montagem (scan `questoes`); otimização futura: usar `questoes_materia_stats` + queries por matéria (como `SimuladoService`).

**Sem Cloud Functions adicionais.**

---

## Impacto de performance

- Montagem: O(N) questões em memória — aceitável até ~5k questões.
- Prova: estado local (SharedPreferences rascunho) — offline parcial.
- Entrega: batch de `registrarResposta` sequencial — pode ser otimizado com batch write futuro.

---

## Impacto pedagógico

1. **Realismo:** formato 100q / 4h alinha expectativa INEP.
2. **Diagnóstico:** breakdown matéria/subtema + top fraquezas.
3. **Ação:** plano de estudo linkado a flashcards e questões existentes.
4. **Motivação:** dashboard de evolução (melhor nota, média, tendência).

---

## Integração Premium futura

- Feature flag `revalida_official_simulator` pronta (`FeatureGate`).
- Paywall sugerido (não implementado):
  - 1 prova oficial grátis/mês
  - Análise completa + plano de fraquezas = Premium
  - Histórico ilimitado = Premium
- Infra `PaywallGate` existente — aplicar na landing ou pós-1º simulado.

---

## Novas dependências

**Nenhuma.**

---

## Arquivos criados

### Domínio
- `lib/domain/revalida_official/revalida_official_config.dart`
- `lib/domain/revalida_official/revalida_performance_calculator.dart`
- `lib/domain/revalida_official/revalida_evolution_summary.dart`
- `lib/domain/revalida_official/revalida_exceptions.dart`

### Modelos / serviços
- `lib/models/revalida_simulation_model.dart`
- `lib/services/revalida_official/revalida_official_service.dart`
- `lib/services/revalida_official/revalida_simulation_repository.dart`
- `lib/services/revalida_official/revalida_weakness_study_service.dart`

### UI
- `lib/screens/revalida_official/revalida_official_landing_page.dart`
- `lib/screens/revalida_official/revalida_official_play_page.dart`
- `lib/screens/revalida_official/revalida_official_review_page.dart`
- `lib/screens/revalida_official/revalida_performance_page.dart`
- `lib/screens/revalida_official/revalida_evolution_dashboard_page.dart`
- `lib/screens/revalida_official/revalida_weakness_study_page.dart`
- `lib/widgets/revalida_official/revalida_exam_question_card.dart`

### Testes
- `test/revalida_official/revalida_performance_calculator_test.dart`
- `test/revalida_official/revalida_simulation_persistence_test.dart`
- `test/revalida_official/revalida_session_store_test.dart`

### Documentação
- `docs/REVALIDA_OFFICIAL_SIMULATOR_PRE_REPORT.md`
- `docs/REVALIDA_OFFICIAL_SIMULATOR_IMPLEMENTATION_REPORT.md`

### Alterados (integração)
- `lib/core/feature_flags/feature_modules.dart`
- `lib/core/constants/firestore_paths.dart`
- `lib/screens/home_page.dart`
- `firestore.rules`
- `firestore.indexes.json`

---

## Testes

**10/10** passando em `test/revalida_official/`  
**flutter analyze:** sem issues

---

## Restrições respeitadas

- ✓ Simulados comuns inalterados
- ✓ `QuestaoCard` inalterado
- ✓ Flashcards, OSCE, Mercado Pago, cronograma inalterados
- ✓ Sem paywall ativo (flag only)
- ✓ Sem IA no plano de correção

---

## Deploy necessário

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Sem deploy das rules, writes em `revalida_simulations` falharão em produção.
