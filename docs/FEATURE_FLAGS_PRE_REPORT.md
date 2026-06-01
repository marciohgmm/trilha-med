# Feature Flags — Relatório pré-implementação (Etapa 1)

**Data:** 2026-05-19  
**Escopo:** Auditoria somente leitura.

---

## 1. Resumo

O app não possuía **feature flags** remotas. Módulos eram sempre visíveis após login. O Painel Mestre gerencia comercial/RBAC, mas não liga/desliga funcionalidades do app sem nova versão.

---

## 2. Pontos de entrada por área

### HomePage (`lib/screens/home_page.dart`)
| Entrada | Destino | Flag sugerida |
|---------|---------|---------------|
| Estudar por Flashcards | `HomeDashboardPage` | `flashcards` |
| Estudar por Questões | `QuestoesPorTemaPage` | `questoes` |
| Fase Prática | `OsceLobbyPage` | `fase_pratica` |
| Ferramentas Médicas | `MedicalToolsPage` | `ferramentas_medicas` |
| EventsSection | Live events | `live_events` |

### HomeDashboardPage (flashcards — mesmo arquivo)
| Entrada | Destino | Flag |
|---------|---------|------|
| Card "Ver cronograma" | `CronogramaPage` | `cronograma` |
| Matérias → subtemas | Flashcards | `flashcards` |

### MainNavigationPage
| Aba | Conteúdo | Flag |
|-----|----------|------|
| Início | `HomePage` | (herda flags da home) |
| Perfil | `PerfilPage` | — |

### Questões
| Entrada | Arquivo | Flag |
|---------|---------|------|
| Lista por matéria | `questoes_por_tema_page.dart` | `questoes` |
| Fazer Simulado | `SimuladoFiltrosPage` | `simulados` |
| Histórico simulados | `SimuladoHistoricoPage` | `simulados` |

### Simulados
Fluxo: Questões → filtros → play → resultado. **Sem botão direto na Home.**

### Cronograma
`CronogramaPage` — acesso via dashboard flashcards (card "Estudo de hoje").

### Fase Prática / OSCE
| Entrada | Destino | Flag |
|---------|---------|------|
| Home → Fase Prática | `OsceLobbyPage` | `fase_pratica` |
| OSCE salas/estações | `osce_station_page.dart`, etc. | `osce` |
| Biblioteca modelos | `PracticalPhaseLandingPage` | `fase_pratica` (não na Home) |

### Live Events
`EventsSection` na Home → `LiveEventPlayPage` / lobby.

### Ferramentas Médicas
Home → `MedicalToolsPage`.

### Premium / Monetização
| Entrada | Flag |
|---------|------|
| Planos, assinatura, checkout MP | `premium` (doc reservado; **não** desligar checkout nesta fase) |
| Marketplace futuro | `marketplace` |

### Painel Mestre
`MasterAdminShell` — 15+ módulos RBAC. **Sem** gestão de flags (até esta implementação).

---

## 3. Classificação de risco (sem flags)

| Módulo | Risco operacional | Custo Firestore |
|--------|-------------------|-----------------|
| Flashcards | Alto (core) | Alto (reads) |
| Questões / Simulados | Alto | Alto |
| OSCE / Fase Prática | Médio | Médio |
| Live Events | Médio | Médio + FCM |
| Cronograma | Médio | Baixo |
| Ferramentas Médicas | Baixo | Baixo |
| Premium | Crítico (receita) | Médio |

---

## 4. Necessidade de limite remoto

| Prioridade | Módulos |
|------------|---------|
| Imediata | flashcards, questoes, osce, live_events (incidentes / manutenção) |
| Alta | simulados, cronograma, fase_pratica, ferramentas_medicas |
| Reservada | premium, marketplace (flags existem; UX monetização preservada) |

---

## 5. Referências

- `lib/screens/home_page.dart`
- `lib/screens/main_navigation_page.dart`
- `lib/screens/master_admin/master_admin_destinations.dart`
- `firestore.rules` — coleções `platform_*`
