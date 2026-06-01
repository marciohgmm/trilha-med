# Pré-relatório LGPD — Produção pública

**Data:** 2026-05-19  
**Modo:** Auditoria somente leitura (Etapa A)  
**Escopo:** Auth, cadastro, perfil, Firestore, Analytics, FCM, Mercado Pago, platform analytics/audit

---

## 1. Inventário de dados pessoais

| Dado | Sensível? | Onde | Finalidade |
|------|-----------|------|------------|
| E-mail, UID | Identificador | Firebase Auth, `users/{uid}` | Conta |
| Nome, telefone, cidade | Pessoal | `users/{uid}` | Perfil |
| Senha | Credencial | Auth (hash) | Autenticação |
| Progresso flashcards | Comportamento | `users/.../progresso` | Estudo |
| Progresso questões | Comportamento | `users/.../progresso_questoes` | Estudo |
| Simulados histórico | Comportamento | `users/.../simulados_historico` | Simulados |
| Cronograma | Comportamento | `users/.../cronograma_*` | Planejamento |
| FCM tokens | Identificador técnico | `users.fcmTokens`, `platform_fcm_users` | Push |
| Preferências push | Preferência | `users.notificationPrefs` | Notificações |
| displayName, photoUrl | Pessoal (mínimo) | `users/.../public_profile` | Exibição social |
| Eventos GA4 + espelho | Comportamento | Firebase Analytics, `platform_analytics_events` | Métricas |
| Pagamentos / assinaturas | Financeiro | `platform_payments`, `platform_subscriptions` | Monetização |
| Entitlements | Contratual | `users/.../platform_entitlements` | Acesso Premium |
| Relatórios suporte | Conteúdo + UID | `notificacoes_admin` | Suporte |
| OSCE avaliações | Comportamento + UID | `osce_evaluations` | OSCE |

**Dados sensíveis (saúde):** conteúdo médico educacional em flashcards/questões **não** é dado do titular; progresso de estudo em matérias médicas é dado **comportamental**, não prontuário clínico.

---

## 2. Retenção (estado atual)

| Sistema | Prazo documentado no código |
|---------|----------------------------|
| `platform_analytics_events` | 90 dias (`expireAt` + purge job) |
| Demais coleções `users/*` | Indefinido |
| `platform_payments` / audit | Indefinido (retenção financeira implícita) |
| GA4 | Política Google |

---

## 3. Operadores terceiros

| Operador | Serviço | Dados |
|----------|---------|-------|
| Google Firebase | Auth, Firestore, Functions, FCM, Analytics | Conforme uso |
| Google Play / App Store | Distribuição | Conforme loja |
| Mercado Pago | Pagamentos | E-mail pagador, transação (Checkout Pro) |

**DPA:** contratual (fora do app).

---

## 4. Compartilhamento

- Não há venda de dados a terceiros no código.
- Perfil público: `public_profile` legível por usuários autenticados.
- Relatórios de erro incluem trechos de conteúdo para admins.

---

## 5. Fluxos atuais (pré-implementação)

| Fluxo | Estado |
|-------|--------|
| Exclusão de conta | **Inexistente** (`users` delete só admin nas rules) |
| Exportação | **Inexistente** (export admin só flashcards) |
| Consentimento | **Inexistente** (sem checkbox legal no cadastro) |
| Política / Termos | **Inexistentes** no app |
| Canal LGPD | Suporte genérico (`notificacoes_admin`) |

---

## 6. Respostas obrigatórias

| Pergunta | Resposta |
|----------|----------|
| Consentimento registrável? | **Não** |
| Política de privacidade? | **Não** (no app) |
| Termo de uso? | **Não** (no app) |
| Exclusão de conta? | **Não** |
| Portabilidade? | **Não** |
| Canal LGPD? | **Parcial** (suporte, sem DPO dedicado) |

---

## 7. Plano de implementação (Etapas B–H)

- Telas legais + versões `policyVersion` / `termsVersion`
- `users/{uid}/legal_acceptances` + gate pós-login
- `PrivacyCenterPage`, export JSON, `deleteMyAccount` (Function)
- Preservar `platform_payments` e `platform_audit_logs` financeiros
- Sem alterar fluxos de estudo, MP, OSCE, flashcards, questões

---

*Etapa A concluída — base para `docs/LGPD_IMPLEMENTATION_REPORT.md`.*
