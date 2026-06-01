# Simulado Revalida Oficial — Auditoria de Custo (Pré-otimização)

**Data:** 2026-05-19  
**Escopo:** Somente leitura — estado antes da otimização.

---

## Serviços mapeados

| Serviço | Arquivo | Papel na montagem |
|---------|---------|-------------------|
| **RevalidaOfficialService** | `lib/services/revalida_official/revalida_official_service.dart` | `montarProvaOficial()` — **scan completo** |
| **QuestaoService** | `lib/services/questao_service.dart` | CRUD; não usado na montagem |
| **SimuladoService** | `lib/services/simulado_service.dart` | Referência: `whereIn` por matéria, early stop |
| **QuestaoMateriaStatsService** | `lib/services/questao_materia_stats_service.dart` | Catálogo `questoes_materia_stats` |
| **RevalidaWeaknessStudyService** | `lib/services/revalida_official/revalida_weakness_study_service.dart` | Pós-prova; `where(materia)` **sem limit** (fora do escopo desta otimização) |

---

## Query atual (montagem da prova)

```dart
// revalida_official_service.dart — montarProvaOficial()
final snap = await _db.collection('questoes').get();
```

| Aspecto | Valor |
|---------|-------|
| Tipo | **Collection scan completo** |
| Filtro Firestore | Nenhum |
| Limit | Nenhum |
| Índice | N/A (full scan) |

---

## Respostas às 6 perguntas

| # | Pergunta | Resposta |
|---|----------|----------|
| 1 | **Quantas leituras hoje?** | **N** = total de documentos em `questoes` (ex.: 2.000 questões → **2.000 reads/prova**) + 0 na entrega (progresso é write) |
| 2 | **Scan completo?** | **Sim** — `collection('questoes').get()` |
| 3 | **Questões não utilizadas carregadas?** | **Sim** — todas são lidas; apenas ~100 selecionadas após shuffle |
| 4 | **Cache?** | **Não** — cada início de prova refaz scan completo |
| 5 | **Catálogo agregado disponível?** | **Sim** — `questoes_materia_stats` (nome + total por matéria); `questoes_subtema_catalog` (pares matéria/subtema) |
| 6 | **Índice adequado?** | **Sim** para `where('materia', isEqualTo: …)` — single-field index automático; `whereIn` até 10 matérias (padrão SimuladoService) |

---

## Comparação com SimuladoService (referência)

| | Simulado comum | Revalida Oficial (antes) |
|--|----------------|--------------------------|
| Lista matérias | `questoes_materia_stats` | Não usa |
| Query questões | `whereIn('materia', batch≤10)` | `get()` total |
| Early stop | Sim (≥ quantidade) | Não |
| Leituras típicas | Σ questões das matérias até atingir N | **Todas** |

---

## Projeção de custo (Firestore reads — montagem)

| Questões no banco | Reads/prova (antes) | 1.000 provas/mês | 10.000 provas/mês |
|-------------------|---------------------|------------------|-------------------|
| 500 | 500 | 500k | 5M |
| 2.000 | 2.000 | 2M | 20M |
| 10.000 | 10.000 | 10M | 100M |

Free tier: 50k reads/dia → **1 prova de 2k questões ≈ estoura cota diária com ~25 usuários**.

---

## Otimização planejada (sem alterar UX/regras)

1. Substituir scan por queries `where('materia')` + `limit` proporcional à quota
2. Usar `questoes_materia_stats` para quotas e limites
3. Cache local TTL reutilizável entre simulados
4. Métricas internas `revalida_simulator.build`
