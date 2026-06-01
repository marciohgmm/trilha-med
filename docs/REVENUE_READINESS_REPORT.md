# Relatório de prontidão para receita (Revenue Readiness)

**Data:** 2026-05-19  
**Modo:** Auditoria somente leitura — **nenhum código alterado**  
**Objetivo:** Avaliar se o sistema está pronto para os **primeiros assinantes pagantes**.

**Documentos relacionados:** `docs/MVP_COMMERCIAL_IMPLEMENTATION.md`, `docs/MERCADO_PAGO_IMPLEMENTATION.md`, `docs/MONETIZATION_AUDIT.md` (parcialmente desatualizado), `docs/MONETIZATION_STRATEGY.md`.

---

## 1. Veredito executivo

| Pergunta | Resposta curta |
|----------|----------------|
| **Pronto para cobrar?** | **Parcial** — stack técnica de pagamento existe; depende de **deploy + secrets + plano com preço + webhook MP**. |
| **Pronto para vender valor?** | **Não** — quase **nenhuma feature** do app está protegida por paywall; benefícios Premium são em grande parte **aspiracionais**. |
| **Recomendação** | Aceitar **1º assinante piloto** via checkout **ou** concessão manual, **desde que** expectativa alinhada (“apoio antecipado” / beta pago) **ou** proteger **≥1 feature** antes de marketing amplo. |

**Classificação global:** **Parcial** (infraestrutura comercial **Pronta**; produto monetizado **Não implementado**).

---

## 2. Respostas às 6 perguntas obrigatórias

### 2.1 Um usuário consegue pagar hoje?

**Resposta: Parcial — sim no código, condicional em produção.**

| Requisito | Estado |
|-----------|--------|
| Tela de planos + botões MP | **Pronto** — `PlansPage` chama `createMercadoPagoCheckout` e abre URL externa |
| Cloud Function `createMercadoPagoCheckout` | **Pronto** — `functions/src/createCheckout.ts` |
| Plano Premium com `priceMonthly` / `priceYearly` > 0 | **Operacional** — admin cria em Painel Mestre → Planos |
| Secret `MERCADOPAGO_ACCESS_TOKEN` | **Deploy** — não verificável no repo |
| Webhook `mercadopagoWebhook` registrado no painel MP | **Deploy** — URL + eventos `payment` |
| `MERCADOPAGO_WEBHOOK_URL` / `notification_url` na preferência | **Parcial** — param opcional; se vazio, IPN pode não chegar |
| Usuário logado com e-mail verificado | **Pronto** — `AuthCheck` exige `emailVerified` |

**Fluxo atual (código):**

```
Perfil → Planos → Assinar mensal/anual
  → Callable createMercadoPagoCheckout (southamerica-east1)
  → platform_payments/{id} status pending
  → Browser / app Mercado Pago (Checkout Pro)
  → Webhook valida pagamento na API MP
  → activatePremiumFromPayment
```

**Bloqueadores típicos fora do código:** functions não deployadas, token sandbox vs produção, plano sem preço, webhook mal configurado, back_urls apontando para rotas web **sem roteamento Flutter** (ver §4.3).

---

### 2.2 O acesso premium é liberado automaticamente?

**Resposta: Pronto — após webhook aprovado (não no retorno do browser).**

| Etapa | Implementação |
|-------|----------------|
| Pagamento `approved` | `functions/src/webhook.ts` → `activatePremiumFromPayment` |
| Assinatura | `platform_subscriptions` — `active`, `currentPeriodEnd` (+30 ou +365 dias) |
| Entitlement | `users/{uid}/platform_entitlements` — chave `premium`, `expiresAt` alinhado |
| Idempotência | Se `payment.status === succeeded`, não reprocessa |
| Extensão de período | Renovação manual (nova compra) **estende** fim se assinatura ainda ativa |
| UI aluno | `CommercialAccessService.watchAccess` → `MySubscriptionPage` atualiza em tempo real |

**Importante:** O app **não** ativa premium no cliente. `CheckoutReturnPage` só registra analytics e orienta “aguarde alguns segundos” — correto do ponto de vista de segurança.

**Gap:** `CheckoutReturnPage` em `success` chama `logPurchaseApproved` **antes** do webhook — pode inflar métricas GA4/Firestore espelho; **não** concede acesso indevido.

---

### 2.3 O acesso premium é removido corretamente?

**Resposta: Parcial — boa cobertura server-side; renovação automática ausente.**

| Evento | Comportamento | Status |
|--------|---------------|--------|
| Pagamento `refunded` / `charged_back` | Cancela assinatura + desativa entitlement `premium` (preserva lifetime/cortesia/beta) | **Pronto** |
| Pagamento `cancelled` / `rejected` | Atualiza pagamento; cancela assinatura vinculada se existir | **Pronto** |
| Fim do período (`currentPeriodEnd`) | `expireSubscriptionsScheduled` (diário 06:00 UTC ≈ 03:00 BRT) | **Pronto** |
| Revogação admin | `CommercialAdminService.revokeAccess` | **Pronto** |
| Renovação automática (cartão recorrente) | **Não** — Checkout Pro é **compra avulsa** por período | **Não implementado** |
| Chargeback após meses | Depende de webhook MP | **Parcial** (operacional) |

**Risco de produto:** Após expirar, o aluno **continua usando** todo o conteúdo “gratuito” (flashcards, questões, OSCE, etc.) — só perde status Premium **sem bloqueio de tela** (ver 2.5).

---

### 2.4 O usuário percebe valor suficiente para assinar?

**Resposta: Parcial / fraco para conversão em escala.**

| Fator | Avaliação |
|-------|-----------|
| Comparação Gratuito vs Premium | **Pronto** — `PlansPage` + tabela de benefícios |
| Benefícios listados | Muitos com ressalva **“quando ativados”** (`commercial_plan_catalog.dart`) |
| Diferença **sentida** no app | **Baixa** — mesmo conteúdo core acessível sem pagar |
| Prova social / trial | **Não implementado** |
| Suporte prioritário / live priority | **Não evidenciado** no fluxo do aluno |
| Propagandas removidas para premium | Serviço de ads existe; **não integrado** na Home do aluno |

**Conclusão:** A página de planos **vende** benefícios; o produto **ainda não entrega** a maior parte deles de forma exclusiva. Risco de **churn** e reclamação (“paguei e nada mudou”).

---

### 2.5 Existem funcionalidades premium realmente protegidas?

**Resposta: Não implementado (enforcement).**

| Mecanismo | Estado |
|-----------|--------|
| `PaywallGate` / `PaywallGuard` | Widget e API **existem** (`lib/widgets/commercial/paywall_gate.dart`) |
| Uso em telas do aluno | **Zero referências** fora do próprio arquivo |
| Flashcards, questões, cronograma, OSCE, Live | **Sem gate** (documentado em `MERCADO_PAGO_IMPLEMENTATION.md` §10) |
| Fase prática, simulados | **Sem** `hasPremium` / `PaywallGuard` nas telas |
| Segmentação de campanhas ads | `AdvertisingCampaignService` usa `hasPremiumAccess` — **só no Painel Mestre**, não no feed aluno |
| Firestore rules por entitlement | **Não** — conteúdo protegido por `isSignedIn` + escopo de query (P0-3), não por plano |

**Único “gate” indireto:** concessão manual ou futuro uso de `PaywallGate` — hoje **opt-in não aplicado**.

---

### 2.6 Qual o caminho mínimo para o primeiro assinante?

**Caminho A — Pagamento real (recomendado para validar stack)**

1. **Deploy** `firestore:rules`, `firestore:indexes`, functions:  
   `createMercadoPagoCheckout`, `mercadopagoWebhook`, `expireSubscriptionsScheduled`
2. Configurar secrets: `MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_WEBHOOK_URL` (URL pública da function)
3. Painel MP: webhook → eventos de pagamento; credenciais de **produção** ou sandbox para piloto
4. Painel Mestre → **Planos**: criar/ativar Premium com preços > 0 e benefícios honestos
5. Piloto com 1 usuário: login → Perfil → Planos → assinar → pagar → aguardar webhook
6. Validar: `platform_payments` succeeded, `platform_subscriptions` active, entitlement `premium`, **Minha Assinatura** = Ativo
7. **Comunicar** ao piloto o que Premium **efetivamente** libera hoje (ou aplicar `PaywallGate` em 1 feature antes)

**Caminho B — Primeiro assinante sem MP (mais rápido, sem validar gateway)**

1. Painel Mestre → Assinaturas → **Conceder acesso** (cortesia, promocional com data, ou vitalício)
2. Aluno confirma em **Minha Assinatura**
3. Usar para onboarding de embaixador; MP pode vir na semana seguinte

**Caminho mínimo de produto (evitar churn):**

- Envolver **uma** tela premium real com `PaywallGate` (ex.: Fase Prática ou simulado avançado) **ou**
- Ajustar copy dos benefícios para refletir apenas o que está liberado + roadmap público

---

## 3. Classificação por área auditada

Legenda: **Pronto** | **Parcial** | **Não implementado**

| Área | Classificação | Evidência resumida |
|------|---------------|-------------------|
| **Mercado Pago** | **Parcial** | SDK server-side em Functions; secrets e webhook são operacionais; sem Assinaturas MP nativas (recorrência) |
| **Checkout** | **Parcial** | Callable + `PlansPage` + `platform_payments`; cupom **sem desconto no valor**; seller/affiliate **não expostos** na UI |
| **Pós-compra** | **Parcial** | Webhook ativa acesso; `CheckoutReturnPage` existe mas **sem rotas** em `main.dart` / web; retorno mobile fraco |
| **Assinaturas** | **Pronto** | Modelo, repo, webhook, job de expiração, Painel Mestre lista/concede |
| **Entitlements** | **Pronto** | Subcoleção `users/.../platform_entitlements`; webhook + admin; rules: escrita só admin |
| **PaywallGate** | **Não implementado** | Código pronto, **não usado** em nenhuma tela |
| **Minha Assinatura** | **Pronto** | Stream de acesso, status, datas, seller/affiliate/cupom, link para planos |
| **PlansPage** | **Parcial** | UI completa + checkout; depende de plano Firestore e login |
| **Painel Mestre Comercial** | **Pronto** | Planos, assinaturas, pagamentos (abas), cupons, afiliados, vendedores, parceiros, ads, concessão manual, analytics comercial |
| **Cupons** | **Parcial** | CRUD admin + campo na checkout; `resolveCouponId` só grava ID; **sem** `discountValue` na preferência; **sem** validar `maxUses` / validade |
| **Afiliados** | **Parcial** | CRUD + `conversions++` no webhook; **sem** link/código na jornada do aluno |
| **Vendedores** | **Parcial** | CRUD + `totalSales++`; **sem** atribuição na UI de checkout |

---

## 4. Análise detalhada por componente

### 4.1 Mercado Pago

**Arquivos:** `functions/src/createCheckout.ts`, `functions/src/webhook.ts`, `functions/src/config.ts`, `lib/application/commercial/mercado_pago_checkout_service.dart`

| Item | Detalhe |
|------|---------|
| Modelo | Checkout Pro (pagamento único por período) |
| Região | `southamerica-east1` |
| Validação webhook | Consulta pagamento na API MP (não confia só no body) |
| Referência externa | `platform_payments` doc id |
| Sandbox | `MERCADOPAGO_SANDBOX` alterna `sandbox_init_point` |

**Gaps:** Assinatura recorrente MP (PreApproval); conciliação de pendentes; alertas se webhook falhar.

---

### 4.2 Checkout

| Capacidade | Status |
|------------|--------|
| Autenticação obrigatória | Sim |
| Plano inativo / sem preço | Erro `failed-precondition` |
| Gravação `platform_payments` | Admin SDK na Function |
| Abertura URL externa | `url_launcher` |
| Analytics `checkout_start` | Sim |
| Cupom na UI | Campo texto → enviado ao callable |
| Desconto no `unit_price` | **Não** |
| Seller / affiliate no checkout | Parâmetros existem no callable; **PlansPage não envia** |

---

### 4.3 Pós-compra

| Item | Status |
|------|--------|
| Ativação | Webhook → assinatura + entitlement |
| Feedback aluno | SnackBar “complete no MP…” + Minha Assinatura |
| `CheckoutReturnPage` | Implementada; URLs default `revalida-cards.web.app/checkout/*` |
| Roteamento Flutter Web | **Não encontrado** em `main.dart` — página de retorno pode **404** na web |
| Deep link Android/iOS | **Não implementado** (doc MP §12) |
| E-mail de confirmação | **Não** (MP pode enviar; app não) |

---

### 4.4 Assinaturas e entitlements

**Coleções:** `platform_subscriptions`, `users/{uid}/platform_entitlements`, `platform_subscription_plans`

**Regras (segurança):**

- Cliente **não** cria/atualiza pagamentos nem assinaturas pagas
- Entitlements: **write** apenas `isAppAdmin()` — webhook usa Admin SDK ✓

**Cliente:** `CommercialAccessService` combina assinatura ativa + entitlements válidos; chaves premium incluem cortesia e beta.

---

### 4.5 PaywallGate

Documentação (`MVP_COMMERCIAL_IMPLEMENTATION.md`) deixa explícito: **opt-in**, flashcards/questões sem paywall.

**Busca no código:** `PaywallGate` / `PaywallGuard` — **apenas** `paywall_gate.dart`.

**Impacto:** Pagante e não pagante têm a **mesma** experiência de estudo.

---

### 4.6 Minha Assinatura e PlansPage

| Tela | Entrada | Função |
|------|---------|--------|
| `PlansPage` | Perfil → Planos | Comparação + checkout |
| `MySubscriptionPage` | Perfil → Minha Assinatura | Status, expiração, entitlements, CTA planos |

**Pronto** para transparência pós-compra; não substitui valor percebido.

---

### 4.7 Painel Mestre Comercial

| Módulo | CRUD | Observação |
|--------|------|------------|
| Dashboard | Leitura | Receita, assinantes, conversões seller/affiliate |
| Analytics | Leitura | Funil checkout → compra (agregados P1-6) |
| Planos | CRUD | Preços e benefícios |
| Assinaturas | Lista + conceder/revogar | Texto vazio ainda menciona “checkout não integrado” — **copy desatualizada** |
| Pagamentos | Lista por status | Aprovados / pendentes / reembolsos |
| Cupons / Afiliados / Vendedores | CRUD | Formulários em `master_admin_commercial_forms.dart` |
| Propagandas / Parceiros | CRUD | Sem vínculo forte com paywall aluno |

**Pronto** para operação interna do primeiro lote de assinantes.

---

### 4.8 Cupons, afiliados e vendedores

| Funcionalidade | Admin | Checkout | Pós-pagamento |
|----------------|-------|----------|---------------|
| Cupom | CRUD | Código opcional | `usedCount++` |
| Desconto real | Modelo `discountType/Value` | **Não aplicado ao amount** | — |
| Limite / validade cupom | Campos no modelo | **Não validado** na Function | — |
| Afiliado | CRUD | Param opcional (não na UI) | `conversions++` |
| Vendedor | CRUD | Param opcional (não na UI) | `totalSales++` |
| Comissão / repasse automático | — | — | **Não implementado** |

---

## 5. Matriz de riscos para o 1º assinante

| Risco | Severidade | Mitigação |
|-------|------------|-----------|
| Paga e não vê diferença no app | **Alta** | Paywall em ≥1 feature ou copy alinhada |
| Webhook não configurado | **Alta** | Checklist deploy + teste sandbox |
| Retorno web 404 | Média | Rotas `/checkout/*` ou remover dependência de back_url |
| Cupom inválido ainda paga preço cheio | Média | Validar cupom no callable + feedback |
| Expectativa de renovação automática | Média | Deixar claro: renovar manualmente até PreApproval |
| Documentação interna contraditória | Baixa | Atualizar empty states do Painel Mestre |

---

## 6. Plano de ação recomendado (sem código nesta auditoria)

### Fase 0 — Operacional (1–2 dias) — desbloqueia cobrança

- [ ] Deploy functions MP + secrets + webhook URL
- [ ] Plano Premium ativo com preços em produção (ou sandbox controlado)
- [ ] Teste E2E: pagamento → webhook → Minha Assinatura
- [ ] Verificar índices `platform_subscriptions` (`status` + `currentPeriodEnd`)

### Fase 1 — Produto mínimo vendável (3–7 dias)

- [ ] Aplicar `PaywallGate` em **1** feature acordada (ex.: `practical_phase_*` ou simulado premium)
- [ ] Ajustar benefícios em `CommercialPlanCatalog` / plano Firestore ao que está liberado
- [ ] Rotas web ou deep link para `CheckoutReturnPage`
- [ ] Atualizar mensagens do Painel Mestre (“checkout integrado”)

### Fase 2 — Conversão e atribuição (1–2 semanas)

- [ ] Desconto de cupom no `unit_price` + validação `maxUses` / datas
- [ ] Query params ou deep link: `?coupon=` / `?affiliate=` na `PlansPage`
- [ ] Trial ou garantia de 7 dias (produto + política)
- [ ] Exibir/remover ads para não premium (se ads forem lançados no feed)

### Fase 3 — Escala (backlog)

- [ ] Assinatura recorrente MP (PreApproval) ou Stripe
- [ ] Portal de cancelamento / gestão de cartão
- [ ] Rules ou Functions checando entitlement em features sensíveis server-side
- [ ] E-mails transacionais (ativação, expiração, falha de pagamento)

---

## 7. Checklist “go / no-go” — primeiro assinante pago

| Critério | Obrigatório? | Status típico hoje |
|----------|--------------|-------------------|
| Function checkout deployada | Sim | Verificar ambiente |
| Webhook MP ativo e testado | Sim | Verificar ambiente |
| Plano com preço > 0 | Sim | Admin |
| Aluno vê status em Minha Assinatura | Sim | Pronto |
| Premium libera **algo** exclusivo no app | **Recomendado forte** | Não |
| Política de reembolso / suporte definida | Sim | Fora do código |
| Copy alinhada ao que está entregue | Sim | Parcial |

**Go** para piloto fechado (5–20 usuários) com expectativa explícita: **sim**, se Fase 0 completa.  
**Go** para marketing aberto “Premium completo”: **não** até Fase 1.

---

## 8. Referências de código (principais)

| Tema | Caminho |
|------|---------|
| Checkout callable | `functions/src/createCheckout.ts` |
| Webhook / expiração | `functions/src/webhook.ts`, `functions/src/subscriptionService.ts` |
| Cliente checkout | `lib/application/commercial/mercado_pago_checkout_service.dart` |
| Planos aluno | `lib/screens/commercial/plans_page.dart` |
| Assinatura aluno | `lib/screens/commercial/my_subscription_page.dart` |
| Acesso consolidado | `lib/application/commercial/commercial_access_service.dart` |
| Paywall (não usado) | `lib/widgets/commercial/paywall_gate.dart` |
| Concessão admin | `lib/application/commercial/commercial_admin_service.dart` |
| Rules comercial | `firestore.rules` (§ `platform_*`, entitlements) |
| Benefícios marketing | `lib/data/commercial_plan_catalog.dart` |

---

## 9. Síntese final

O projeto evoluiu de “schema + admin read-only” (`MONETIZATION_AUDIT.md`) para **checkout Mercado Pago funcional no repositório**, com **ativação automática server-side** e **Painel Mestre comercial operável**. O gargalo para receita recorrente não é mais “não dá para cobrar”, e sim:

1. **Operação** (deploy, webhook, plano precificado)  
2. **Produto** (nenhum paywall aplicado → pouco valor percebido)  
3. **Comercial** (cupom/afiliado/vendedor incompletos na jornada de compra)

**Primeiro assinante:** viável **esta semana** via Caminho A ou B do §2.6, desde que expectativas e, idealmente, **uma feature premium real**, estejam alinhadas.

---

*Auditoria estática do repositório — validar sempre em ambiente Firebase + Mercado Pago antes de campanha paga.*
