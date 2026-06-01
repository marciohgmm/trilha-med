# Simulado Revalida Oficial — Pré-relatório (Auditoria)

**Data:** 2026-05-19  
**Escopo:** Auditoria somente leitura — nenhum código alterado nesta etapa.

---

## 1. SimuladoFiltrosPage

**Arquivo:** `lib/screens/simulado/simulado_filtros_page.dart`

| Aspecto | Estado atual |
|---------|--------------|
| Entrada | `QuestoesPorTemaPage` → botão "Fazer Simulado" (FeatureGate `simulados`) |
| Configuração | Quantidade (25/50/75/100), matérias, tipo (todas/erradas), status resolução |
| Montagem | `SimuladoService.montarSimulado()` com loading dialog |
| Destino | `SimuladoPlayPage` via `pushReplacement` |

---

## 2. SimuladoResultadoPage

**Arquivo:** `lib/screens/simulado/simulado_resultado_page.dart`

| Aspecto | Estado atual |
|---------|--------------|
| Dados exibidos | Percentual, acertos, erros, não respondidas, tempo |
| Análise por matéria | **Não** |
| Análise por subtema | **Não** |
| Plano de correção | **Não** |
| Ações | Voltar às questões; ver histórico genérico |

---

## 3. SimuladoService

**Arquivo:** `lib/services/simulado_service.dart`

| Método | Função |
|--------|--------|
| `montarSimulado` | Coleta questões por matéria (batch `whereIn` 10 matérias), filtra progresso, shuffle, take N |
| `salvarHistorico` | Grava em `users/{uid}/simulados_historico` |
| `streamHistorico` | Últimos 30 simulados |
| `carregarProgressoUsuario` | Lê `progresso_questoes` |

**Distribuição:** coleta por matéria em lotes, **sem quota equilibrada** — shuffle final aleatório.

---

## 4. QuestaoService

**Arquivo:** `lib/services/questao_service.dart`

- CRUD e streams por matéria/subtema/tema
- `registrarResposta` — fire-and-forget ao responder (`QuestaoCard`)
- `progressoQuestoesStream` — base das estatísticas
- Campo `flashcardId` em `QuestaoModel` — vínculo questão ↔ flashcard

---

## 5. EstatisticasQuestoesPage

**Arquivo:** `lib/screens/estatisticas_questoes_page.dart`

- Agrega **histórico global** de `progresso_questoes` (não por simulado)
- Por matéria + por tema (legado `tema`, não `subtema`)
- **Sem** vínculo com simulados concluídos

---

## 6. Histórico de simulados

**Arquivo:** `lib/screens/simulado/simulado_historico_page.dart`  
**Persistência:** `users/{uid}/simulados_historico/{id}`

Campos: filtros, totais, percentual, tempo, `questaoIds`.  
**Sem** breakdown por matéria/subtema. **Sem** coleção `revalida_simulations`.

---

## 7. Banco de questões

- Firestore `questoes` — conteúdo dinâmico (admin)
- Agregação: `questoes_materia_stats`, `questoes_subtema_catalog`
- Hierarquia: matéria → subtema (`content_hierarchy_utils.dart`)
- Sample local: `lib/data/banco_perguntas.dart` (6 questões — dev only)

---

## 8. Cronômetro existente

**SimuladoPlayPage:** timer **progressivo** (elapsed), tick 1s, exibido no AppBar.  
**Sem** limite de tempo. **Sem** countdown oficial.

**StudyTimerService:** Pomodoro para estudo (flashcards/questões) — **independente** do simulado.

---

## 9. Sistema de métricas

- `AnalyticsFeatures.simuladoStart` / `simuladoComplete` — analytics feature tracker
- Histórico Firestore em `simulados_historico`
- Estatísticas globais em `progresso_questoes`
- **Gap:** métricas por simulado oficial, evolução temporal, fraquezas

---

## 10. Integração com Flashcards

| Integração | Existe? |
|------------|---------|
| `QuestaoModel.flashcardId` | Sim (campo no modelo) |
| Navegação simulado → flashcard | **Não** |
| Plano de estudo pós-erro | **Não** |
| Cronograma reage a simulado | **Não** |

Flashcards usam coleção `flashcards` + catálogo `flashcards_subtema_catalog`. Sem leitura cruzada no fluxo de simulado.

---

## 11. Integração com Cronograma

**Arquivo:** `lib/services/cronograma_service.dart`

- Baseado em pares matéria/subtema de **flashcards**
- **Zero** integração com simulados ou questões erradas

---

## 12. SimuladoPlayPage (comportamento de prova)

| Requisito prova oficial | Estado |
|-------------------------|--------|
| Ocultar gabarito durante prova | **Não** — `QuestaoCard` mostra certo/errado imediato |
| Ocultar desempenho parcial | **Não** — header exibe acertos/erros |
| Navegação livre | Parcial — Anterior/Próxima; PageView bloqueia swipe |
| Revisão antes de entregar | **Não** — só alerta se pendentes |
| Confirmação final | Diálogo simples se pendentes |

**Rascunho local:** `SimuladoSessionStore` (SharedPreferences) — respostas com bool acertou.

---

## Respostas às 10 perguntas

| # | Pergunta | Resposta |
|---|----------|----------|
| 1 | Como os simulados são gerados hoje? | `SimuladoService.montarSimulado`: lê progresso, busca questões por matéria (Firestore `whereIn`), aplica filtros, shuffle, retorna N questões. |
| 2 | Existe distribuição automática por matéria? | **Parcial** — busca de todas as matérias, mas **sem quota equilibrada**; proporção depende do que cada query retorna primeiro. |
| 3 | Existe distribuição automática por subtema? | **Não** |
| 4 | Existe cronômetro? | **Sim** — elapsed time, sem limite. |
| 5 | Existe bloqueio de gabarito até o final? | **Não** — feedback imediato no `QuestaoCard`. |
| 6 | Existe revisão final antes da entrega? | **Não** — apenas aviso de questões não respondidas. |
| 7 | Existe análise por matéria? | **Não** no resultado do simulado (só em estatísticas globais). |
| 8 | Existe análise por subtema? | **Não** |
| 9 | Existe integração com flashcards? | **Não** no fluxo (campo `flashcardId` existe no modelo). |
| 10 | Existe integração com cronograma? | **Não** |

---

## Infraestrutura reutilizável

| Componente | Reuso planejado |
|------------|-----------------|
| `SimuladoService._coletarPorMaterias` | Base para seleção por matéria |
| `QuestaoMateriaStatsService` | Quotas equilibradas |
| `QuestaoModel` | Breakdown matéria/subtema |
| `FeatureGate` / `FeatureModules` | Flag `revalida_official_simulator` |
| `SimuladoSessionStore` | Padrão para rascunho Revalida (chave separada) |
| Firestore rules `users/{uid}/{sub}` | Modelo para `revalida_simulations` |

---

## Restrições do escopo (implementação)

- Não alterar `SimuladoFiltrosPage`, `SimuladoPlayPage`, `SimuladoResultadoPage`
- Não alterar `QuestaoCard` comportamento padrão (criar widget exam-mode separado)
- Não alterar flashcards, OSCE, Mercado Pago, cronograma
- Paywall: infra only (feature flag), sem bloqueio
