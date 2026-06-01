# Simulado Revalida Oficial — Relatório de Otimização de Custo

**Data:** 2026-05-19  
**Escopo:** Otimização de leituras Firestore — sem alteração de UX, telas ou regras de negócio.

---

## ANTES × DEPOIS

| Métrica | Antes | Depois |
|---------|-------|--------|
| Query principal | `questoes.get()` (scan total) | `where('materia')` + `limit` por matéria |
| Catálogo agregado | Não usado | `questoes_materia_stats` |
| Cache | Não | SharedPreferences, TTL 30 min |
| Métricas internas | Não | `[revalida_simulator.build]` |
| Seleção equilibrada 100q | Mantida | Mantida |
| UX / telas | — | **Inalteradas** |

---

## Leituras por prova (montagem)

### Fórmula ANTES

\[
reads_{antes} = N_{questoes}
\]

### Fórmula DEPOIS (sem cache)

\[
reads_{depois} = M + \sum_{i=1}^{M} \min(total_i,\; quota_i \times 3 + 10)
\]

Onde:
- \(M\) = matérias em `questoes_materia_stats`
- \(quota_i\) ≈ \(100 / M\)
- Fallback (raro): matérias deficitárias podem exigir leitura adicional até `total_i`

### Com cache hit (TTL 30 min)

\[
reads_{cache} = 0
\]

---

## Cenário referência (10 matérias, 200 questões/matéria, banco 2.000)

| Modo | Leituras | vs Antes |
|------|----------|----------|
| **Antes** | 2.000 | — |
| **Depois (1ª prova)** | ~410 (10 stats + 10×40 limit) | **−79,5%** |
| **Depois (cache hit)** | 0 | **−100%** |

---

## Impacto por escala de usuários

Estimativa: **1 prova/usuário/dia**, banco 2.000 questões, 10 matérias.

| Usuários | Reads/dia ANTES | Reads/dia DEPOIS (sem cache) | Reads/dia DEPOIS (50% cache hit) | Economia |
|----------|-----------------|------------------------------|----------------------------------|----------|
| **100** | 200.000 | 41.000 | 20.500 | **79–90%** |
| **1.000** | 2.000.000 | 410.000 | 205.000 | **79–90%** |
| **10.000** | 20.000.000 | 4.100.000 | 2.050.000 | **79–90%** |

> Free tier Firestore: 50k reads/dia. Com **antes**, ~25 usuários/dia estouram a cota. Com **depois**, ~120 usuários/dia (sem cache) ou ~240+ (50% cache).

---

## Implementação

### Novos arquivos

| Arquivo | Função |
|---------|--------|
| `revalida_official_exam_builder.dart` | Montagem otimizada |
| `revalida_question_pool_cache.dart` | Cache TTL |
| `revalida_simulator_build_metrics.dart` | Métricas + log |

### Alterados

| Arquivo | Mudança |
|---------|---------|
| `revalida_official_service.dart` | Delega para `RevalidaOfficialExamBuilder` |
| `revalida_official_config.dart` | `poolCacheTtl`, multiplicadores de fetch |

### Log interno (exemplo)

```
[revalida_simulator.build] {durationMs: 842, reads: 85, evaluated: 80, selected: 100, cacheHit: false, materias: 10}
```

---

## Testes

| Suite | Resultado |
|-------|-----------|
| `test/revalida_official/` (todos) | 10+ testes |
| `revalida_cost_optimization_test.dart` | Projeção ANTES/DEPOIS |
| `revalida_question_pool_cache_test.dart` | TTL e invalidação |

```bash
flutter test test/revalida_official/
flutter analyze
```

---

## Restrições respeitadas

- ✓ Sem novas funcionalidades visíveis
- ✓ UX inalterada
- ✓ Regras de negócio inalteradas (100q equilibradas, shuffle)
- ✓ Telas inalteradas
- ✓ Simulados comuns inalterados

---

## Melhorias futuras (opcional)

1. Fallback com paginação (`startAfter`) para evitar re-leitura em matérias grandes
2. Otimizar `RevalidaWeaknessStudyService` (`where(materia).get()` sem limit)
3. Índice composto `materia + status` se filtro `disponivelParaEstudo` migrar para query
