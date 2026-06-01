# Rate Limiting — Relatório de implementação (Etapas B–G)

**Data:** 2026-05-19  
**Pré-relatório:** [RATE_LIMITING_PRE_REPORT.md](./RATE_LIMITING_PRE_REPORT.md)

---

## ANTES × DEPOIS

| Área | Antes | Depois |
|------|-------|--------|
| Callables críticas | Sem limite por usuário/IP | `assertRateLimitForCallable` + `resource-exhausted` |
| Auth login/cadastro | Só limites Firebase padrão | Blocking (`beforeUserSignedIn`, `beforeUserCreated`) |
| Auth reset senha | — | Callable `rateLimitPasswordReset` + mesma mensagem de erro (sem nova tela) |
| Contadores | — | Coleção `platform_rate_limits` (Admin SDK only) |
| Abuso | Logs esparsos | `platform_audit_logs` + JSON estruturado em bloqueio |
| Firestore rules | — | `platform_rate_limits` read/write negados ao cliente |

**Inalterado:** UX aluno, fluxo Mercado Pago, estudo, OSCE, flashcards, questões, webhook MP.

---

## Etapa B — Rate Limit Core

**Coleção:** `platform_rate_limits/{docId}`

| Campo | Descrição |
|-------|-----------|
| `uid` | Quando escopo uid |
| `action` | Ex.: `checkout.mercado_pago` |
| `windowStart` | Início da janela |
| `count` | Requisições na janela |
| `lastRequest` | Server timestamp |
| `ipHash` | SHA-256 truncado (quando aplicável) |
| `subjectKey` | Diagnóstico (`uid:…`, `ip:…`, `email:…`) |

**Módulos:** `functions/src/rateLimit/*` — `RateLimitService` via `enforceRateLimits`, janela fixa, transação Firestore.

**Escopos:** por usuário, IP, e-mail (auth), por ação, por janela configurável.

---

## Etapa C — Limites aplicados

| Ação | Limite |
|------|--------|
| `checkout.mercado_pago` | 3/h uid + 6/h IP |
| `payment.reconcile_my` | 10/h uid |
| `push.campaign_create` | 20/h uid (admin) |
| `push.live_broadcast` | 60/h uid |
| `fcm.register_token` | 60/h uid + 120/h IP |
| `account.delete` | 2/dia uid |
| `auth.login` | 20/h email + 40/h IP |
| `auth.signup` | 10/h email + 20/h IP |
| `auth.reset_password` | 5/h email + 15/h IP |

**Auth:** sem mudança nas telas Flutter; blocking transparente.

**Mercado Pago:** webhook e URLs de checkout **inalterados**.

---

## Etapa D — Auditoria de abuso

Em bloqueio: `logRateLimitAudit` →

- `console.log` JSON (`tag: rate_limit`, `uid`, `action`, `blocked`, `reason`)
- `platform_audit_logs` com `eventType: rate_limit.blocked`

---

## Etapa E — Firestore

```text
match /platform_rate_limits/{docId} {
  allow read, write: if false;
}
```

Usuário comum não lê, escreve nem apaga contadores.

---

## Etapa F — Testes

| Caso | Arquivo | Resultado |
|------|---------|-----------|
| A) Abaixo do limite | `rateLimitCore.test.mjs` | `allowed: true` |
| B) Acima do limite | `rateLimitCore.test.mjs` | `allowed: false` |
| C) Admin painel | Limites por uid (20 push/h) | Config + wiring |
| D) Checkout MP | `createCheckout.ts` + limites 3/h | Wiring verificado |
| E) Delete account | 2/dia + wiring | Core + enforcement tests |
| Rules | `rate_limit_firestore_rules_test.dart` | deny all client |

**Comando:** `cd functions && npm test` (inclui novos testes após build).

---

## Abuso reduzido?

**Sim**, para callables e auth listados — scripts repetidos recebem `resource-exhausted` e deixam trilha em auditoria.

## Endpoints protegidos?

8 callables + 3 blocking auth functions. Webhook MP e schedulers fora do escopo (correto).

## Impacto financeiro esperado?

Redução de invocações abusivas (push, reconcile, checkout) e tentativas de auth; efeito pleno após deploy.

## Deploy necessário?

1. `firebase deploy --only functions`
2. `firebase deploy --only firestore:rules`
3. Firebase Console → Authentication → **Blocking functions** — associar `rateLimitBeforeSignIn`, `rateLimitBeforeCreate`
4. Opcional: secrets `RATE_LIMIT_IP_SALT`, `RATE_LIMIT_EMAIL_SALT`

## Riscos remanescentes

- Leitura massiva Firestore (estudo) sem rate limit por operação nesta fase
- `platform_audit_logs` ainda aceita `create` de clientes autenticados
- IP atrás de NAT compartilhado pode afetar limite por IP (checkout/auth)
- Blocking functions exigem configuração no Console

## Impacto usuário / admin

| Grupo | Impacto |
|-------|---------|
| Aluno | Mensagem genérica só se exceder limite (raro em uso normal) |
| Admin push | 20 campanhas/h — suficiente para operação normal |
| Checkout | 3 tentativas/h — evita spam; uso legítimo preservado |

---

## Arquivos principais

- `functions/src/rateLimit/rateLimitService.ts`
- `functions/src/rateLimit/rateLimitConfig.ts`
- `functions/src/rateLimit/authBlocking.ts`
- `firestore.rules` — `platform_rate_limits`
