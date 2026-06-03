# Estratégia de Monetização de Conteúdo — Trilha Med

**Data:** maio/2026  
**Modo:** Auditoria e estratégia — **nenhum código alterado**  
**Base técnica:** estado atual do repositório + infraestrutura comercial (MVP, Mercado Pago, campanhas)

Documentos relacionados: [MONETIZATION_AUDIT.md](./MONETIZATION_AUDIT.md), [MVP_COMMERCIAL_IMPLEMENTATION.md](./MVP_COMMERCIAL_IMPLEMENTATION.md), [MERCADO_PAGO_IMPLEMENTATION.md](./MERCADO_PAGO_IMPLEMENTATION.md), [ADVERTISING_SYSTEM_IMPLEMENTATION.md](./ADVERTISING_SYSTEM_IMPLEMENTATION.md)

---

## Sumário executivo

O app hoje entrega **100% do conteúdo de estudo gratuitamente** para qualquer usuário autenticado. A infraestrutura comercial (planos, checkout Mercado Pago, entitlements, `PaywallGate`) está pronta, mas **nenhuma tela de estudo usa paywall**.

A estratégia recomendada é **freemium generoso no core** (flashcards + questões por tema + cronograma) e **Premium no que gera resultado mensurável** (simulados, fase prática catalogada, analytics avançados, OSCE ampliado, eventos ao vivo prioritários). **Premium Plus** foca em exclusividade, suporte e pacotes institucionais.

Estimativa realista para mercado Revalida (BR): conversão free→paid **3–8%** com paywall bem calibrado; retenção D30 pode cair **5–15%** se o core for restrito cedo demais — por isso o core permanece gratuito.

---

## Diagnóstico por funcionalidade (estado atual)

| Funcionalidade | O que existe | Paywall hoje | Valor percebido | Notas |
|----------------|--------------|--------------|-----------------|-------|
| **Flashcards** | Matérias, subtemas, SRS, cronograma, busca, timer | Nenhum | Alto (hábito diário) | Motor de retenção — não bloquear |
| **Questões** | Por tema/subtema, progresso, timer | Nenhum | Alto | Core freemium |
| **Simulados** | Filtros, sessão cronometrada, histórico, resultado | Nenhum | Muito alto | Principal gatilho de conversão |
| **OSCE** | Lobby multiplayer, salas, estações, avaliação, histórico | Nenhum | Alto (diferencial) | Home chama “Fase Prática” mas abre OSCE |
| **Fase Prática (catálogo)** | Landing, dashboard, modelos publicados | Nenhum | Alto | **UI órfã** — não linkada na Home |
| **Live Events** | Carousel na Home, play, eliminação, espectador | Nenhum | Médio-alto (FOMO) | Copy já diz “premium” |
| **Ranking / Performance** | Stats questões, grid OSCE, detalhe por especialidade | Nenhum | Médio | Sem leaderboard global |
| **Estatísticas** | `EstatisticasQuestoesPage` básica | Nenhum | Médio | Premium = camada avançada |
| **Admin / Painel Mestre** | CRUD conteúdo + comercial | RBAC admin | N/A (B2B interno) | Não monetizar para aluno |

**Dívida de produto antes de cobrar:** (1) separar nomenclatura OSCE vs Fase Prática catalogada; (2) linkar `PracticalPhaseLandingPage` na navegação; (3) aplicar `PaywallGate` só onde a estratégia indicar; (4) opcionalmente reforçar rules Firestore para conteúdo premium.

---

## 1. O que deve permanecer gratuito

Objetivo: **aquisição, hábito e prova de valor** — o aluno precisa sentir que o app “funciona de verdade” antes de pagar.

### Core de estudo (sempre gratuito)

| Recurso | Escopo gratuito sugerido |
|---------|--------------------------|
| **Flashcards** | Acesso ilimitado a decks publicados; cronograma; busca; timer de estudo |
| **Questões por tema** | Resolução por subtema; progresso básico (acertos/erros) |
| **Login e perfil** | Conta, configurações, relógio de estudo |
| **Planos / Minha Assinatura** | Telas comerciais (já existem) |

### Freemium com limites suaves (gratuito, não bloqueio total)

| Recurso | Limite gratuito sugerido |
|---------|--------------------------|
| **Simulados** | 1 simulado completo / mês **ou** até 30 questões por simulado |
| **OSCE multiplayer** | 2 salas / semana; casos “básicos” (subset do catálogo) |
| **Live Events** | Participação em eventos **abertos**; fila normal (sem prioridade) |
| **Estatísticas** | Visão resumida por matéria (taxa de acerto, total respondido) |
| **Fase Prática (catálogo)** | Preview: 1–2 modelos publicados ou seções introdutórias |

### Sempre gratuito (não comercializar)

- **Painel admin de conteúdo** (`AdminPage`) — apenas admins
- **Painel Mestre** — RBAC comercial
- **Suporte básico** (FAQ, reportar problema) — manter; Premium pode ter fila prioritária

**Princípio:** quem só usa flashcards + questões **nunca** deve ver paywall intrusivo no meio do estudo.

---

## 2. O que deveria ser Premium

Alinhado ao catálogo já declarado em `commercial_plan_catalog.dart` e ao que o código **promete mas não entrega**.

| Recurso | Premium (desbloqueio total) | Justificativa |
|---------|------------------------------|---------------|
| **Simulados** | Ilimitados; filtros avançados; histórico completo; modo prova longa | Proximidade com dia da prova = alta disposição a pagar |
| **Fase Prática (catálogo)** | Todos os modelos/módulos publicados; anexos; links | Conteúdo curado, difícil de replicar |
| **Relatórios avançados** | `PerformanceDetailPage`, tendências, comparativo por especialidade OSCE, exportável | “Onde estudar mais” — valor claro |
| **OSCE ampliado** | Casos completos; salas ilimitadas; histórico de avaliações sem limite | Diferencial vs concorrentes só de questões |
| **Live Events** | Prioridade de fila; acesso a eventos **Premium-only**; badge no perfil | FOMO + status |
| **Experiência** | Sem anúncios (`AdPlacementSlot` só para free) | Monetização alternativa para quem não paga |
| **Suporte** | Prioridade (SLA 24–48h) | Baixo custo marginal, alto valor percebido |

**Preço de referência (mercado preparatório médico BR):** R$ 39–79/mês ou R$ 299–599/ano — calibrar após teste A/B no Painel Mestre.

---

## 3. O que deveria ser Premium Plus

Tier **acima do Premium** — para power users e bundles. Requer novo plano Firestore (`PlanTier` ou plano separado `premium_plus`).

| Recurso | Premium Plus |
|---------|--------------|
| **Simulados** | Pacotes “Revalida inteira”; simulados comentados; gabarito expandido |
| **OSCE** | Casos exclusivos Plus; gravação/replay de sessão (futuro); mentoria em grupo |
| **Live Events** | Torneios exclusivos Plus; prêmios/reconhecimento |
| **Analytics** | Dashboard unificado (flashcards + questões + OSCE + simulados); metas semanais; PDF mensal |
| **Ranking** | Leaderboard global/regional; histórico de posição |
| **Acesso antecipado** | Novos módulos 2–4 semanas antes |
| **Suporte** | Chat prioritário ou plantão semanal |

**Preço sugerido:** 1,5–2× o Premium (ex.: R$ 99–129/mês) ou bundle anual com desconto menor que 2×12.

**Não lançar Plus no dia 1** — introduzir 3–6 meses após Premium estabilizado, quando houver conteúdo exclusivo suficiente.

---

## 4. O que pode gerar mais conversão

Ordenado por **impacto esperado × facilidade de implementação** (com infra atual).

| # | Gatilho | Mecanismo | Conversão estimada* |
|---|---------|-----------|---------------------|
| 1 | **Simulado bloqueado após limite** | Paywall ao iniciar 2º simulado/mês | Alto |
| 2 | **Resultado do simulado + CTA** | Após `SimuladoResultadoPage`: “Desbloqueie análise completa” | Alto |
| 3 | **Preview Fase Prática** | 1 modelo free → paywall no dashboard | Médio-alto |
| 4 | **Live Event lotado / prioridade** | Mensagem “Premium entra primeiro” | Médio (FOMO) |
| 5 | **Performance OSCE bloqueada** | Grid visível, detalhe premium | Médio |
| 6 | **Trial 7 dias** | Cortesia via `CommercialAdminService` ou MP | Médio |
| 7 | **Cupom de curso parceiro** | `platform_coupons` + vendedor/afiliado | Médio (B2B2C) |
| 8 | **Anúncios no free** | Banner home/questões só para não-assinantes | Baixo receita, empurra upgrade |

\*Ordem de magnitude para base orgânica Revalida: **0,5–2% por touchpoint** isolado; combinação calibrada **3–8%** free→paid em 90 dias.

**Evitar:** paywall na primeira questão ou no meio de sessão de flashcards (conversão baixa, churn alto).

---

## 5. Onde aplicar PaywallGate

Widget existente: `lib/widgets/commercial/paywall_gate.dart`  
Entitlement padrão: `CommercialEntitlementKey.premium` (inclui lifetime, cortesia, beta via `hasPremiumAccess`).

| Prioridade | Tela / fluxo | Entitlement | Comportamento sugerido |
|------------|--------------|-------------|------------------------|
| **P0** | `SimuladoFiltrosPage` (botão iniciar) | `premium` | Bloqueio após cota free; CTA Planos |
| **P0** | `PracticalPhaseDashboardPage` / `PracticalPhaseDetailPage` | `premium` | Preview free na landing; resto bloqueado |
| **P1** | `PerformanceDetailPage` | `premium` | Resumo free no lobby; detalhe premium |
| **P1** | `SimuladoHistoricoPage` (histórico completo) | `premium` | Último simulado free |
| **P1** | `LiveEventPlayPage` (eventos marcados premium) | `premium` | Eventos “abertos” continuam free |
| **P2** | `EstatisticasQuestoesPage` (aba avançada) | `premium` | Stats básicos free |
| **P2** | `OsceLobbyPage` (criar sala além da cota) | `premium` | 2 salas/semana free |
| **P2** | `OsceEvaluationHistoryPage` (histórico longo) | `premium` | Últimas N avaliações free |
| **P3** | Leaderboard global (quando existir) | `premium` ou Plus | Plus se exclusivo |
| **Não** | `TelaFlashcards`, `QuestoesPage`, `CronogramaPage` | — | Sem gate |
| **Não** | `LoginPage`, `HomePage` (cards de entrada) | — | Sem gate |

**Implementação gradual:** feature flag por módulo (ex. `PaywallFlags.simuladosEnabled`) antes de ligar tudo.

---

## 6. Impacto estimado em retenção e conversão

Estimativas qualitativas para **base típica** app preparatório médico (n ≈ 1.000–5.000 MAU). Validar com analytics pós-lançamento.

### Cenário A — Core 100% free, Premium só em simulados + fase prática

| Métrica | Impacto estimado |
|---------|------------------|
| Retenção D7 | Neutro a **+2%** (valor claro no free) |
| Retenção D30 | Neutro |
| Conversão free→Premium (90d) | **4–7%** |
| Churn pós-paywall | Baixo se limite simulado for claro upfront |

### Cenário B — Questões limitadas (ex.: 50/dia)

| Métrica | Impacto estimado |
|---------|------------------|
| Retenção D7 | **−5 a −15%** |
| Conversão | **+1–3%** (subsidia churn) |
| Veredito | **Não recomendado** para Revalida |

### Cenário C — Anúncios no free + Premium sem ads

| Métrica | Impacto estimado |
|---------|------------------|
| Retenção D30 (free) | **−3 a −8%** se invasivo |
| Conversão | **+0,5–2%** |
| Receita ads | Baixa vs assinatura; usar como **empurrão**, não pilar |

### Cenário D — Beta fechado (cortesia) → lançamento com paywall

| Métrica | Impacto estimado |
|---------|------------------|
| Retenção beta | Alta (gratuidade + pertencimento) |
| Conversão no D-day | **10–25%** dos beta ativos se aviso prévio + desconto fundador |
| Risco | Backlash se paywall atingir core sem transição |

**Recomendação:** Cenário A + anúncios discretos opcionais + trial/cupom fundador no lançamento.

---

## 7. Estratégia Freemium recomendada

### Pilares

1. **Grátis generoso:** flashcards + questões + cronograma ilimitados.
2. **Premium = performance:** simulados, fase prática, analytics, OSCE ampliado.
3. **Transparência:** limites free visíveis em Planos e antes do paywall (não surpresa).
4. **Prova social:** contador de simulados feitos, eventos ao vivo na Home.
5. **Monetização dupla:** assinatura + parcerias B2B + ads leves no free.

### Jornada do usuário

```
Cadastro → Estudo free (7–14 dias hábito)
        → 1º simulado free completo
        → Resultado + gap analysis (parcial)
        → CTA Premium / trial 7 dias
        → Conversão ou continua free (ads discretos)
```

### Planos comerciais (Firestore)

| Plano | Tier | Público |
|-------|------|---------|
| Gratuito | `free` | Todos |
| Premium | `premium` | Aluno individual |
| Premium Plus | `premium_plus` (novo) | Power user / pós-lançamento |
| Cortesia / Vitalício | entitlements | Beta, parceiros, sorteios |
| Institucional | parceria + lote | Escolas/cursos |

### KPIs

- MAU, D1/D7/D30 retention
- Simulados iniciados / usuário / mês
- Taxa free→trial, trial→paid
- MRR, churn mensal, LTV/CAC
- Conversão por vendedor/afiliado (já rastreável)

---

## 8. Estratégia para beta fechado

### Objetivo

Validar conteúdo, OSCE multiplayer e live events **sem cobrança**, construindo base engajada e feedback.

### Fases

| Fase | Duração | Acesso | Entitlement |
|------|---------|--------|-------------|
| **Beta fechado** | 8–12 semanas | Convite / lista de espera | `beta_tester` + `courtesy_access` ou Premium manual |
| **Beta ampliado** | 4 semanas | Cadastro aberto, cap de usuários | Mesmo + comunicação “preço fundador” |
| **Pré-lançamento** | 2 semanas | Congelar grants manuais; testar paywall em staging | Flag interna |

### Regras

- Conceder `beta_tester` via Painel Mestre (`CommercialAdminService.grantBetaTester`).
- **Documentar** que o beta é gratuito **até data X** (e-mail + banner in-app).
- Coletar NPS e entrevistas com quem usou simulados e OSCE.
- **Não** prometer “sempre grátis” para simulados ilimitados.

### Oferta fundador (conversão beta → paid)

- 30–40% desconto no **primeiro ano** ou preço travado vitalício para primeiros 200 assinantes.
- Cupom `BETA2026` em `platform_coupons` ligado a afiliado/campanha.

---

## 9. Estratégia para lançamento oficial

### Pré-requisitos (checklist)

- [ ] Mercado Pago em produção + webhook estável
- [ ] Planos Premium cadastrados com preço real
- [ ] Paywall P0 (simulados + fase prática) ativo
- [ ] `PracticalPhaseLandingPage` linkada na Home (separar label OSCE)
- [ ] Copy Planos = enforcement real
- [ ] Firestore rules: opcional reforço leitura conteúdo premium
- [ ] Suporte preparado para “cobrança / acesso”

### Sequência de lançamento (4 semanas)

| Semana | Ação |
|--------|------|
| **T−2** | E-mail beta: data do paywall + benefício fundador |
| **T−1** | Banner Home + Perfil; simulado free restante visível |
| **T0** | Ativar paywall simulados + fase prática; MP checkout live |
| **T+1** | Live Event “lançamento” (engajamento + CTA Premium) |
| **T+2–4** | Ajuste limites free com base em conversão e churn |

### Comunicação

- **Grátis para sempre:** flashcards, questões por tema, cronograma.
- **Premium:** simulados ilimitados, fase prática, relatórios, OSCE completo, eventos prioritários.

### Riscos e mitigação

| Risco | Mitigação |
|-------|-----------|
| Reclamação “era tudo grátis” | Comunicação prévia; período de graça pós-lançamento (7 dias Premium) |
| MP falha | Grant manual + fila suporte |
| Conteúdo premium vazio | Só ligar paywall quando houver ≥ N modelos simulado/fase prática |

---

## 10. Estratégia para escolas, cursos preparatórios e faculdades

### Modelo B2B2C

| Segmento | Oferta | Monetização |
|----------|--------|-------------|
| **Cursinho preparatório** | Licença por turma (50–500 alunos) | Fee anual + rev share ou preço por seat |
| **Faculdade / internato** | OSCE + fase prática para disciplina | Contrato institucional |
| **Influenciador / professor** | Link afiliado + cupom | `platform_affiliates` + comissão |
| **Hospital / residency program** | Casos OSCE customizados | Parceria + `platform_partnerships` |

### Pacotes sugeridos

| Pacote | Inclusão | Preço indicativo (referência) |
|--------|----------|-------------------------------|
| **Turma S** | 30 seats Premium 6 meses | R$ 2.500–4.000 |
| **Turma M** | 100 seats + dashboard coordenador | R$ 8.000–15.000 |
| **Institucional** | White-label leve, casos custom, SSO futuro | Sob consulta |

### Funcionalidades institucionais (roadmap)

- Dashboard coordenador: progresso agregado da turma (sem expor dados sensíveis)
- Cupom único por instituição (`applicablePlanIds` + `maxUses`)
- Vendedor dedicado (`platform_sellers`) por contrato
- Relatório mensal PDF para coordenação (Premium Plus ou add-on)

### Faculdades — argumento de venda

- OSCE multiplayer reduz custo de sala simulada.
- Fase prática alinhada a competências clínicas.
- Métricas de desempenho por turma para coordenação de internato.

### Governança

- Contrato + LGPD (dados agregados; DPA se necessário).
- Parceiro em `platform_partnerships` com logo, link, cupom (`promoCouponCode`).
- Campanhas segmentadas `AdAudienceSegment.all` ou co-branding na Home (quando ads ativos).

---

## Matriz resumo: Gratuito × Premium × Premium Plus

| Funcionalidade | Gratuito | Premium | Premium Plus |
|----------------|----------|---------|--------------|
| Flashcards | ✅ Ilimitado | ✅ | ✅ |
| Questões por tema | ✅ Ilimitado | ✅ | ✅ |
| Cronograma / timer | ✅ | ✅ | ✅ |
| Simulados | ⚠️ Cota | ✅ Ilimitado | ✅ + comentados / packs |
| Fase Prática catálogo | ⚠️ Preview | ✅ Completo | ✅ + antecipado |
| OSCE multiplayer | ⚠️ Básico/limitado | ✅ Ampliado | ✅ Exclusivo + extras |
| Live Events | Abertos | Prioridade + exclusivos | Torneios Plus |
| Estatísticas | Resumo | Avançado OSCE/questões | Dashboard unificado + PDF |
| Ranking global | — | Opcional | ✅ |
| Anúncios | Sim (discreto) | Não | Não |
| Suporte | Padrão | Prioritário | Premium (chat/plantão) |
| Admin / Painel Mestre | — | — | — (RBAC) |

---

## Roadmap de implementação (produto, não código neste doc)

| Fase | Escopo | Prazo sugerido |
|------|--------|----------------|
| **0** | Corrigir nav Fase Prática vs OSCE; conteúdo premium mínimo | 2–3 semanas |
| **1** | Paywall simulados + fase prática; MP produção | 2 semanas |
| **2** | Analytics premium + limites OSCE | 3 semanas |
| **3** | Live events tier + ads free opt-in | 2 semanas |
| **4** | Premium Plus + ranking + B2B piloto | 6–8 semanas |

---

## Conclusão

A monetização mais **realista e defensável** para o Trilha Med é:

1. **Manter o core de estudo gratuito** (flashcards + questões + cronograma).
2. **Cobrar Premium** onde o aluno mede progresso em direção à prova (simulados, fase prática, relatórios, OSCE completo, live prioritário).
3. **Reservar Premium Plus** para exclusividade e institucional após tração.
4. **Aplicar PaywallGate** primeiro em simulados e fase prática — maior conversão, menor risco de churn.
5. **Usar beta fechado** com entitlement `beta_tester` e oferta fundador na transição.
6. **Escalar receita** com turmas preparatórias via parcerias, cupons e vendedores já modelados no Painel Mestre.

A infraestrutura técnica (checkout, entitlements, admin, campanhas) **suporta esta estratégia**; falta apenas enforcement gradual e alinhamento produto/conteúdo — sem bloquear o hábito de estudo que sustenta retenção.

---

*Documento gerado por auditoria de código e estratégia comercial — maio/2026. Sem alterações de código.*
