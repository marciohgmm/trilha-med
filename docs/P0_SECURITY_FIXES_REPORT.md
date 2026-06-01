# Relatório final — Correções P0 segurança (privilégio + webhook MP)

**Data:** 2026-05-19  
**Pré-relatórios:**  
- `docs/P0_SECURITY_PRIVILEGE_ESCALATION_PRE_REPORT.md`  
- `docs/P0_MERCADOPAGO_WEBHOOK_SECURITY_PRE_REPORT.md`

---

## 1. Resumo executivo

| Bloqueador | Status |
|------------|--------|
| **P0-A** Escalada `isAdmin` / `rbacRoles` | **Corrigido** (Firestore Rules) |
| **P0-B** Webhook MP sem `x-signature` | **Corrigido** (Functions) |

**UX / fluxo comercial:** inalterados (sem mudança de telas do aluno).

---

## 2. P0-A — Antes × Depois

### Antes

- `users/{uid}`: `allow update: if isOwner(userId) || …` **sem** restrição de campos.
- Atacante podia `update({ isAdmin: true, rbacRoles: ['master_admin'] })`.
- `admins/{uid}`: CUD apenas `isFounder()`.

### Depois

| Regra | Comportamento |
|-------|----------------|
| `ownerSafeUserCreate()` | Dono não pode criar doc com `isAdmin`, `rbacRoles`, `roles`, `permissions`. |
| `isOwnerSafeProfileUpdate()` | Dono só altera chaves de perfil/atividade listadas; campos privilegiados **inalterados**. |
| `isAppAdmin()` | Único perfil que pode gravar `isAdmin` / `rbacRoles` (e updates completos). |
| `admins/{uid}` | `create/update/delete`: **somente `isAppAdmin()`** |
| Exceções preservadas | `isOscePerformanceOnlyUpdate`, `isLiveEventRewardGrantToUser` |

**Arquivo:** `firestore.rules` (funções `userPrivilegedFieldKeys`, `isOwnerSafeProfileUpdate`, etc.)

### Privilege escalation eliminada?

**Sim**, para o vetor Firestore direto (auto-`isAdmin` / `rbacRoles`).  
**Residual:** outros P1 do relatório LGPD (audit log aberto, conteúdo legível) permanecem fora deste escopo.

### Impacto

| Público | Impacto |
|---------|---------|
| Aluno | Nenhum (mesmos campos de perfil/progresso). |
| Admin / founder | `grantAdmin`, `assignRolesToUser` continuam via `isAppAdmin()`. |
| Founder | Pode gerenciar `admins/` se `isAppAdmin()` (inclui founder). |

---

## 3. P0-B — Antes × Depois

### Antes

- Webhook processava `data.id` sem validar `x-signature`.
- Spoofing: qualquer HTTP poderia disparar processamento por ID MP.
- Sem auditoria de falhas de autenticação.

### Depois

| Requisito | Implementação |
|-----------|----------------|
| Validar `x-signature` | `validateMercadoPagoWebhookSignature()` — HMAC-SHA256, manifest oficial MP |
| `x-request-id` | Incluído no manifest quando presente |
| Não confiar em status do payload | Mantido: `processMercadoPagoPaymentById` → API MP |
| Rejeitar inválidos | HTTP **401** + `reason` em log/audit |
| Replay | Janela **10 min** via `ts` do header |
| Auditoria | `platform_audit_logs` — `eventType: webhook.mercadopago`, metadata com `timestamp`, `paymentId`, `action`, `success`, `reason` |

**Arquivos novos/alterados:**

- `functions/src/subscription/mercadoPagoWebhookAuth.ts`
- `functions/src/subscription/webhookAudit.ts`
- `functions/src/webhook.ts`
- `functions/src/config.ts` — `MERCADOPAGO_WEBHOOK_SECRET`, `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE`

### Webhook autenticado?

**Sim**, quando `MERCADOPAGO_WEBHOOK_SECRET` está configurado e skip desligado.

### Impacto comercial

- Checkout, ativação, reconciliação: **inalterados**.
- IPN inválido deixa de processar pagamentos (401).

---

## 4. Deploy necessário

```bash
# 1. Firestore rules (obrigatório para P0-A)
firebase deploy --only firestore:rules

# 2. Secret assinatura webhook (painel MP → Webhooks → secret signature)
firebase functions:secrets:set MERCADOPAGO_WEBHOOK_SECRET

# 3. Functions
cd functions && npm run build && npm test
firebase deploy --only functions:mercadopagoWebhook
```

**Produção:** não definir `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true`.

**Dev local:** opcional `MERCADOPAGO_WEBHOOK_SKIP_SIGNATURE=true` para simular IPN sem header.

---

## 5. Testes executados

```bash
cd functions && npm run build && npm test
```

| Caso | Arquivo | Resultado esperado |
|------|---------|-------------------|
| **A** `isAdmin` / `rbacRoles` bloqueados | `security-privilege-rules.test.mjs` | Rules contêm `isOwnerSafeProfileUpdate` / `ownerSafeUserCreate` |
| **B** `admins/` só `isAppAdmin` | `security-privilege-rules.test.mjs` | Sem `isFounder()` em CUD de admins |
| **C** Assinatura inválida | `mercadoPagoWebhookAuth.test.mjs` | `valid: false`, `signature_mismatch` |
| **D** Assinatura válida | `mercadoPagoWebhookAuth.test.mjs` | `valid: true` |
| Webhook HTTP 401 | `mercadoPagoWebhookAuth.test.mjs` | `webhook.ts` contém `status(401)` |

**Nota:** testes A/B validam **política nas rules** (análise estática). Testes de emulador Rules (`@firebase/rules-unit-testing`) podem ser adicionados em fase posterior.

---

## 6. Riscos remanescentes (fora deste P0)

| ID | Tema | Sev. |
|----|------|------|
| L-P0-01–04 | Política privacidade, exclusão/exportação de conta | P0 legal |
| S-P1-01–03 | Audit logs / notificações / analytics daily abertos a `isSignedIn` | P1 |
| S-P1-08–09 | App Check / rate limit em callables | P1 |
| S-P1-04 | Conteúdo flashcards/questões legível por logados | P1 |

---

## 7. Checklist pós-deploy

- [ ] Publicar `firestore.rules`
- [ ] Configurar `MERCADOPAGO_WEBHOOK_SECRET` (mesmo valor do painel MP)
- [ ] Deploy `mercadopagoWebhook`
- [ ] Teste sandbox MP: simulação webhook → 200 + audit `signature_validate` success
- [ ] Teste negativo: POST sem header → 401
- [ ] Confirmar aluno comum não grava `isAdmin` (Console Rules Playground ou script)

---

## 8. Conclusão

Os bloqueadores **P0-A** e **P0-B** de `docs/LGPD_SECURITY_AUDIT.md` foram endereçados **sem alterar UX** nem fluxo comercial do aluno. O app fica **mais próximo de produção** do ponto de vista de segurança técnica; ainda depende de entregas **LGPD documentais** (política, exclusão de conta) antes de loja pública.

---

*Implementação: Etapas 2 e 4 — relatórios Etapas 1, 3 e 6.*
