# Auditoria LGPD, privacidade, segurança e conformidade para produção

**Data:** 2026-05-19  
**Modo:** Somente leitura (código, `firestore.rules`, `storage.rules`, Cloud Functions, app Flutter) — **nenhuma alteração de código**  
**Escopo:** Flutter · Firebase Auth · Firestore · Storage · Cloud Functions · Firebase Analytics · FCM · Mercado Pago · logs administrativos · assinaturas

**Documentos relacionados:** `docs/PREMIUM_SUBSCRIPTION_AUDIT.md`, `docs/P0_SUBSCRIPTION_FIXES_REPORT.md`, `docs/USERS_PRIVACY_S1.md`, `docs/FINAL_AUDIT_POST_IMPLEMENTATION.md`, `firestore.rules`, `storage.rules`

---

## 1. Veredito executivo

| Dimensão | Situação | Comentário |
|----------|----------|------------|
| **LGPD (direitos do titular)** | **Insuficiente** | Não há política/termos no app, exclusão de conta, exportação de dados nem registro de consentimento. |
| **Segurança técnica** | **Parcial** | Melhorias relevantes (S1 `users`, pagamentos só via Functions, P0 assinaturas), mas há escalada de privilégio em rules e webhook MP sem autenticação de origem. |
| **Comercial / financeiro** | **Parcial** | Modelo de pagamento no servidor é sólido; webhook e callables expostos sem rate limit/App Check. |
| **Pronto para loja / produção ampla** | **Não** | Exige fechamento de **P0** legais e de segurança antes de go-live público. |

**Recomendação:** beta fechado apenas com termos/privacidade publicados externamente + plano de exclusão manual, até implementar fluxos LGPD no produto. Não lançar campanha paga em escala sem P0 resolvidos.

---

## 2. Metodologia

1. Revisão de `firestore.rules` e `storage.rules` (controle de acesso e vazamento).  
2. Revisão de Cloud Functions (`createCheckout`, `webhook`, reconciliação, push, analytics).  
3. Revisão Flutter: registro, login, perfil, analytics, checkout, Painel Mestre, relatórios/suporte.  
4. Busca por termos LGPD, exclusão de conta, exportação, consentimento, App Check, rate limit.  
5. Cruzamento com auditorias anteriores (`FINAL_AUDIT_POST_IMPLEMENTATION.md`, `USERS_PRIVACY_S1.md`).

---

## 3. LGPD — achados

### 3.1 Política de Privacidade e Termos de Uso

| ID | Sev. | Achado | Evidência | Impacto |
|----|------|--------|-----------|---------|
| **L-P0-01** | **P0** | **Não há Política de Privacidade nem Termos de Uso** acessíveis no app (telas, links no registro/login, `web/index.html`). | `RegisterScreen`, `LoginPage`, `web/index.html` — sem links legais; `docs/FINAL_AUDIT_POST_IMPLEMENTATION.md` lista como obrigatório para loja, mas não implementado no produto. | Base legal e transparência (Art. 8º e 9º LGPD) indefinidas; rejeição em revisão de loja (Google Play / App Store). |
| **L-P0-02** | **P0** | **Ausência de aceite registrável** (checkbox + versão do documento + timestamp) no cadastro. | `lib/screens/register_screen.dart` — cria conta sem consentimento explícito. | Dificuldade de provar consentimento em disputa ou ANPD. |

### 3.2 Direitos do titular (Art. 18 LGPD)

| ID | Sev. | Achado | Evidência | Impacto |
|----|------|--------|-----------|---------|
| **L-P0-03** | **P0** | **Sem fluxo de exclusão de conta** pelo titular (apagar Auth + dados Firestore/Storage/analytics/FCM). | `PerfilPage` — logout e suporte; `firestore.rules` `users` `delete` só `isAppAdmin()`. Nenhum `deleteUser` / callable de erasure. | Direito de eliminação não atendido de forma autônoma. |
| **L-P0-04** | **P0** | **Sem exportação / portabilidade de dados** pessoais (perfil, progresso, assinatura, eventos). | Export JSON existe só para **flashcards admin** (`admin_page.dart`), não para dados do usuário. | Portabilidade (Art. 18, V) não implementada. |
| **L-P1-01** | **P1** | **Canal de atendimento genérico**, não dedicado a privacidade/DPO. | `PerfilPage` → `notificacoes_admin` tipo `contato_admin`; sem e-mail/URL de encarregado. | Titular pode não saber como exercer direitos LGPD. |
| **L-P1-02** | **P1** | **Política de retenção não documentada no produto** (apenas parcial no backend). | Analytics espelho: 90 dias (`AppAnalyticsService._rawRetentionDays` + `purgeAnalyticsEventsScheduled`); demais coleções sem TTL documentado para o usuário. | Retenção indefinida percebida em `users`, progresso, OSCE, relatórios. |

### 3.3 Dados pessoais tratados (inventário resumido)

| Categoria | Onde | Finalidade aparente | Base legal sugerida |
|-----------|------|---------------------|---------------------|
| E-mail, UID | Auth, `users/{uid}` | Autenticação, conta | Execução de contrato |
| Nome, telefone, cidade | `users` (perfil) | Perfil / suporte | Consentimento / contrato |
| Progresso estudo, cronograma, questões | `users/*` subcoleções | Funcionalidade educacional | Contrato |
| FCM tokens | `users.fcmTokens`, `platform_fcm_users` | Notificações | Consentimento (permissão SO) |
| Eventos analytics | GA4 + `platform_analytics_events` (espelho) | Métricas de produto | Legítimo interesse / consentimento |
| Pagamentos | `platform_payments`, MP | Assinatura Premium | Contrato |
| Relatórios de erro | `notificacoes_admin`, `questao_reports` | Qualidade / suporte | Legítimo interesse |
| Perfil público | `users/{uid}/public_profile` | Exibição entre usuários | Consentimento / informação |

### 3.4 Terceiros e transferência internacional

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **L-P1-03** | **P1** | **Operadores não informados ao titular no app:** Google (Firebase, Analytics), Mercado Pago, possivelmente lojas de apps. | Dependências `pubspec.yaml`; checkout externo MP; sem aviso na UI. |
| **L-P1-04** | **P1** | **DPA / cláusulas contratuais** com Google e MP não referenciadas no produto (esperado em documentação jurídica externa). | Fora do código — gap de governança. |

### 3.5 Consentimento e permissões

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **L-P2-01** | **P2** | FCM solicita permissão (`requestPermission`) sem texto contextual ligado à política de privacidade. | `lib/services/push/fcm_service.dart` |
| **L-P2-02** | **P2** | Biometria + **senha em `FlutterSecureStorage`** (“lembrar senha”) — risco se dispositivo comprometido; não há aviso na UI. | `credenciais_salvas_service.dart`, `login_page.dart` |

### 3.6 Controles LGPD positivos (já existentes)

- **S1 privacidade:** leitura de `users/{uid}` restrita a dono + admin; `public_profile` separado (`firestore.rules` L144–159; `docs/USERS_PRIVACY_S1.md`).  
- **Retenção analytics espelho:** 90 dias + job de purge (`functions/src/analyticsScheduled.ts`).  
- **Espelho Firestore seletivo** — eventos críticos apenas (`AnalyticsMirrorPolicy`).  
- **GA4 desligado em debug** (`!kDebugMode` em `initialize()`).

---

## 4. Segurança da informação — achados

### 4.1 Firestore Rules

| ID | Sev. | Achado | Evidência | Impacto |
|----|------|--------|-----------|---------|
| **S-P0-01** | **P0** | **Escalada de privilégio:** dono pode atualizar **qualquer campo** em `users/{uid}`, incluindo `isAdmin` e `rbacRoles`, sem validação nas rules. | `firestore.rules` L148–151: `allow update: if isOwner(userId) \|\| ...` sem `hasOnly` / proibição de campos sensíveis. `isAppAdmin()` usa `users.isAdmin` (L29–34). | Conta comum pode tornar-se admin no Firestore e editar conteúdo, ver dados de outros usuários, pagamentos (leitura admin). |
| **S-P1-01** | **P1** | **`platform_audit_logs`:** `create` para **qualquer** `isSignedIn()`. | `firestore.rules` L541–544 | Spam, custo, trilha de auditoria não confiável (integridade). |
| **S-P1-02** | **P1** | **`notificacoes_admin`:** `create` para qualquer autenticado. | `firestore.rules` L446–448 | Abuso (volume, conteúdo ofensivo, exfiltração de trechos de cards em reports). |
| **S-P1-03** | **P1** | **`platform_analytics_daily`:** `create, update` para qualquer autenticado. | `firestore.rules` L555–558 | Manipulação de métricas de negócio (DAU, receita agregada). |
| **S-P1-04** | **P1** | **`flashcards` / `questoes`:** leitura ampla para `isSignedIn()` (com alguns limites de list). | `firestore.rules` L210–221 | Vazamento de conteúdo proprietário; scraping por conta válida (mitigação parcial P0-3 conteúdo). |
| **S-P1-05** | **P1** | **`osce_rooms`, `osce_evaluations`, `live_events`:** `read` para todo autenticado. | `firestore.rules` L317, 387, 414 | Metadados de salas/eventos e avaliações visíveis fora do contexto necessário. |
| **S-P1-06** | **P1** | **`platform_rbac_permissions` / `platform_rbac_roles`:** leitura para todo autenticado. | `firestore.rules` L592–599 | Enumeração do modelo de permissões (reconhecimento). |
| **S-P2-01** | **P2** | **`public_profile`:** leitura para todo `isSignedIn()`. | `firestore.rules` L155–156 | Exposição intencional mínima; revisar campos permitidos em `UserPublicProfileService`. |
| **S-P2-02** | **P2** | **`isAdmin()` vs `isAppAdmin()`** em rules de escrita (flashcards usam `isAdmin()` sem flag `users.isAdmin`). | `FINAL_AUDIT` D5 | Inconsistência operacional admin legado. |
| **S-P2-03** | **P2** | **E-mail do founder hardcoded** em rules e Functions. | `firestore.rules` L16; `functions/src/push/adminAuth.ts` | Risco operacional se conta comprometida; preferir custom claims. |

### 4.2 Storage Rules

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **S-P1-07** | **P1** | **`imagenscard/**`:** `allow read: if true` (público sem auth). | `storage.rules` L43–45 |
| **S-P2-04** | **P2** | Demais paths exigem auth; upload admin/OSCE com limite 10 MB — adequado. | `storage.rules` L37–57 |

### 4.3 Cloud Functions

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **S-P0-02** | **P0** | **`mercadopagoWebhook` sem validação de assinatura** (x-signature / secret MP) — qualquer cliente HTTP pode disparar processamento se souber um `payment id` válido. | `functions/src/webhook.ts` — sem HMAC; consulta API MP depois (mitiga spoof parcial, não elimina abuso). |
| **S-P1-08** | **P1** | **Sem Firebase App Check** em callables (`createMercadoPagoCheckout`, `reconcileMyMercadoPagoPayments`, `registerFcmToken`, push admin). | Ausência em `pubspec.yaml` e handlers. |
| **S-P1-09** | **P1** | **Sem rate limiting** por UID/IP em checkout, reconciliação e registro FCM. | `createCheckout.ts`, `paymentReconciliation.ts`, `push/callables.ts` |
| **S-P2-05** | **P2** | Logs estruturados de assinatura podem conter `userId` / `paymentId` — revisar retenção no Cloud Logging. | `subscription/subscriptionLogger.ts` |

### 4.4 Autenticação e enumeração

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **S-P1-10** | **P1** | **Enumeração de contas no login** — mensagens distintas `user-not-found` vs `wrong-password`. | `lib/screens/login_page.dart` L205–207 |
| **S-P2-06** | **P2** | Registro exige verificação de e-mail e sign-out imediato — bom para qualidade de conta. | `register_screen.dart` |
| **S-P2-07** | **P2** | `admins/{uid}` create/update só `isFounder()` — bom; escalada via `users.isAdmin` é o gap principal (S-P0-01). | `firestore.rules` L136–138 |

### 4.5 Exposição de dados pessoais no cliente

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **S-P1-11** | **P1** | **Relatórios de flashcard** enviam pergunta/resposta/explicação completas para `notificacoes_admin` (legítimo para admin, volume alto). | `tela_flashcards.dart` L658–673 |
| **S-P2-08** | **P2** | Painel Mestre lista até 100 usuários com e-mail e UID (somente admin — OK se RBAC + rules corretos). | `master_admin_users_page.dart` |

### 4.6 Controles de segurança positivos

- Pagamentos, assinaturas e entitlements: **cliente não grava** status (`platform_payments`, `platform_subscriptions`, `platform_entitlements` write admin/Functions).  
- Correções **P0 assinatura** (não revogar Premium em recusa; reconciliação; webhook URL obrigatória) — ver `P0_SUBSCRIPTION_FIXES_REPORT.md`.  
- P0-3 conteúdo: limites de list em flashcards/questões.  
- Live Events D2: payout antes de XP em `users`.  
- RBAC + `AdminGate` + auditoria de acesso no app (camada UI; não substitui rules).

---

## 5. Firebase Analytics e Messaging

### 5.1 Analytics (GA4 + espelho)

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **L-P1-05** | **P1** | `setUserId(uid)` envia identificador estável ao Google Analytics. | `app_analytics_service.dart` L67–69, L115 |
| **L-P1-06** | **P1** | Eventos de checkout espelhados com `planId`, `amount`, `paymentId`, cupom — dados de comportamento comercial. | `AnalyticsMirrorPolicy`, rules analytics L547–552 |
| **S-P2-09** | **P2** | Espelho limitado a eventos de negócio + purge 90d — boa prática de minimização. | `analyticsScheduled.ts`, `AnalyticsMirrorPolicy` |

### 5.2 Firebase Cloud Messaging

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **S-P1-12** | **P1** | Tokens FCM gravados em `users/{uid}.fcmTokens` via callable **sem App Check**. | `registerFcmToken` em `push/callables.ts` |
| **S-P2-10** | **P2** | `platform_fcm_users` write bloqueado no cliente; segmentação no servidor — adequado. | `firestore.rules` L572–575 |
| **L-P2-03** | **P2** | Preferências de push em `users` — titular pode alterar (dono); documentar na política. | `push_preferences_service.dart` |

---

## 6. Comercial — Mercado Pago, assinaturas, auditoria

### 6.1 Mercado Pago

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **C-P0-01** | **P0** | Mesmo que **S-P0-02** — webhook público sem autenticação de origem. | `webhook.ts` |
| **C-P1-01** | **P1** | Checkout e reconciliação sem rate limit — criação massiva de `platform_payments` pending. | `createCheckout.ts`, `paymentReconciliation.ts` |
| **C-P2-01** | **P2** | `MERCADOPAGO_ALLOW_CHECKOUT_WITHOUT_WEBHOOK` — risco se ativado em produção. | `functions/src/config.ts` |
| **C-P2-02** | **P2** | Dados de cartão **não** passam pelo app (Checkout Pro) — PCI reduzido; adequado. | `mercado_pago_checkout_service.dart` |

### 6.2 Assinaturas e dados financeiros

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **C-P2-03** | **P2** | Titular lê **apenas** seus pagamentos/assinaturas (`isPaymentOwner` / `isSubscriptionOwner`). | `firestore.rules` L496–505 |
| **C-P2-04** | **P2** | Ativação premium só via Admin SDK (webhook/reconciliação) — integridade financeira reforçada pós P0. | `subscriptionService.ts`, `paymentProcessor.ts` |
| **L-P1-07** | **P1** | Ausência de fluxo in-app de **cancelamento de assinatura** / instrução de direitos do consumidor (CDC + transparência). | `MySubscriptionPage` — planos, sem cancelar MP |

### 6.3 Logs de auditoria

| ID | Sev. | Achado | Evidência |
|----|------|--------|-----------|
| **C-P1-02** | **P1** | Trilha `platform_audit_logs` pode ser **poluída** por qualquer usuário (rules) e por app RBAC (legítimo). | Rules L541–544; `PlatformAuditService.append` |
| **C-P2-05** | **P2** | Pagamentos aprovados geram audit server-side `payment.succeeded` — bom para compliance financeiro. | `subscriptionService.ts` |
| **C-P2-06** | **P2** | Logs imutáveis no cliente (`update, delete: if false`) — bom. | `firestore.rules` L544 |

---

## 7. Matriz consolidada de achados

### P0 — Risco legal ou vazamento crítico

| ID | Tema |
|----|------|
| L-P0-01 | Política de Privacidade ausente no produto |
| L-P0-02 | Aceite de termos/privacidade não registrado |
| L-P0-03 | Exclusão de conta / eliminação de dados |
| L-P0-04 | Exportação / portabilidade de dados do titular |
| S-P0-01 | Escalada de privilégio (`isAdmin` / `rbacRoles` em `users`) |
| S-P0-02 / C-P0-01 | Webhook Mercado Pago sem validação de assinatura |

### P1 — Risco operacional

| ID | Tema |
|----|------|
| L-P1-01 | Canal LGPD / encarregado não dedicado |
| L-P1-02 | Retenção não transparente ao titular |
| L-P1-03 | Operadores terceiros não informados no app |
| L-P1-04 | DPA / governança contratual (fora do código) |
| L-P1-05 | GA4 com userId |
| L-P1-06 | Dados comerciais no espelho analytics |
| L-P1-07 | Cancelamento assinatura / direitos consumidor no app |
| S-P1-01 | Audit logs graváveis por qualquer usuário |
| S-P1-02 | Spam em `notificacoes_admin` |
| S-P1-03 | Manipulação de `platform_analytics_daily` |
| S-P1-04 | Conteúdo flashcards/questões legível por qualquer logado |
| S-P1-05 | Leitura ampla OSCE / Live |
| S-P1-06 | Enumeração modelo RBAC |
| S-P1-07 | Storage `imagenscard` público |
| S-P1-08 | Sem App Check |
| S-P1-09 | Sem rate limiting em Functions |
| S-P1-10 | Enumeração de e-mail no login |
| S-P1-11 | Reports com conteúdo integral de cards |
| S-P1-12 | FCM token registration sem App Check |
| C-P1-01 | Abuso de checkout/reconciliação |
| C-P1-02 | Integridade audit logs comprometível |

### P2 — Melhoria recomendada

| ID | Tema |
|----|------|
| L-P2-01 | Contexto legal antes de permissão push |
| L-P2-02 | Aviso sobre senha salva localmente |
| L-P2-03 | Documentar prefs push na política |
| S-P2-01 a S-P2-10 | Ver seções acima |
| C-P2-01 a C-P2-06 | Ver seções acima |

---

## 8. Checklist de produção (go / no-go)

### Bloqueadores (P0)

- [ ] Publicar **Política de Privacidade** e **Termos** (URL estável + in-app)
- [ ] **Aceite** no registro com versão e data
- [ ] Fluxo **excluir minha conta** (Auth + Firestore + Storage + FCM + pedido MP se aplicável)
- [ ] Fluxo **exportar meus dados** (JSON/ZIP)
- [ ] Corrigir rules: **proibir** `isAdmin`, `rbacRoles` e campos sensíveis em update pelo dono
- [ ] **Validar assinatura** do webhook Mercado Pago (e rejeitar IPN inválidos)

### Alta prioridade (P1) antes de escala

- [ ] Restringir `create` em `platform_audit_logs` e `notificacoes_admin` (Functions ou validação)
- [ ] `platform_analytics_daily` write apenas Admin SDK ou regras com validação de campos
- [ ] App Check + rate limits em callables críticas
- [ ] Canal **privacidade@** / formulário DPO
- [ ] Documento de retenção por coleção
- [ ] Revisar leitura de conteúdo pago (paywall + rules)

### Já adequado ou em evolução positiva

- [x] S1 leitura `users` restrita
- [x] Pagamentos/entitlements não editáveis pelo cliente
- [x] P0 assinaturas (recusa, reconciliação, webhook URL)
- [x] Retenção 90d analytics espelho + job purge
- [x] RBAC e Painel Mestre com auditoria de acesso (UI)

---

## 9. Roadmap sugerido (sem implementar nesta auditoria)

| Fase | Prazo sugerido | Entregas |
|------|----------------|----------|
| **1 — Legal mínimo** | 1–2 semanas | URLs política/termos, aceite no cadastro, canal LGPD, texto sobre terceiros |
| **2 — Segurança crítica** | 1 semana | Rules `users` (campos protegidos), HMAC webhook MP |
| **3 — Direitos do titular** | 2–3 semanas | Callable `deleteMyAccount` + `exportMyData` + runbook manual |
| **4 — Endurecimento** | 2–4 semanas | App Check, rate limits, audit logs só via Functions, paywall + rules conteúdo |

---

## 10. Referências de código (amostra)

**Update permissivo em `users` (escalada):**

```148:151:firestore.rules
      allow update: if isOwner(userId)
        || isAppAdmin()
        || (isSignedIn() && isOscePerformanceOnlyUpdate())
        || isLiveEventRewardGrantToUser(userId);
```

**Audit log aberto:**

```541:544:firestore.rules
    match /platform_audit_logs/{logId} {
      allow read: if isAppAdmin();
      allow create: if isSignedIn();
```

**Webhook sem assinatura:**

```9:57:functions/src/webhook.ts
export const mercadopagoWebhook = onRequest(
  {
    secrets: [mercadoPagoAccessToken],
    region: "southamerica-east1",
  },
  async (req, res) => {
    // ... processa paymentIdFromQuery sem validar x-signature
```

**Registro sem consentimento:**

```87:102:lib/screens/register_screen.dart
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      // ... ensureUserDocument, analytics — sem aceite de termos
```

---

## 11. Conclusão

O projeto evoluiu em **privacidade de perfil (S1)**, **proteção de pagamentos no servidor** e **correções P0 de assinatura**, o que reduz risco financeiro e de vazamento em massa de e-mails. Para **conformidade LGPD e segurança de produção em escala**, permanecem lacunas **estruturais**: documentos legais e direitos do titular no app, **escalada de admin via Firestore rules**, e **webhook Mercado Pago** sem autenticação de origem.

**Veredito final:** **não conforme** para lançamento público amplo até resolução dos itens **P0** listados na seção 8. Adequado para **beta fechado** somente com política/termos publicados externamente, processo manual de exclusão de dados e monitoramento, e correção imediata de **S-P0-01** e **S-P0-02**.

---

*Auditoria somente leitura — nenhum arquivo de aplicativo ou infraestrutura foi modificado.*
