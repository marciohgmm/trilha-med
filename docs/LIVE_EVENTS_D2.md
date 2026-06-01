# Live Events — Correção D2 (recompensas em `users`)

**Status:** Implementado  
**Pré-relatório:** `docs/LIVE_EVENTS_D2_PRE_REPORT.md`  
**Referências:** `FINAL_AUDIT_POST_IMPLEMENTATION.md`, `USERS_PRIVACY_S1.md`, `LIVE_EVENTS_PHASE_B.md`

---

## Problema

A função `isLiveEventRewardGrant()` permitia que **qualquer** usuário autenticado alterasse `xp` e `badges` em `users/{outroUid}`, desde que limitasse os campos — vetor de abuso **P0** (D2).

---

## Solução

### Modelo em duas etapas (mesma transação)

```text
1. live_events/{eventId}/reward_payouts/{userId}  ← create (coordenador)
2. users/{userId}                               ← xp/badges + _liveEventRewardEventId
```

### Regras Firestore

| Path | Quem escreve |
|------|----------------|
| `reward_payouts/{targetUserId}` | `create` — host do evento ou `isAppAdmin()` |
| `users/{targetUserId}` (xp/badges) | Update só com payout existente + `grantedBy == auth.uid` + coordenador do `eventId` |

Removida a regra ampla `isSignedIn() && isLiveEventRewardGrant()`.

### Cliente (`LiveEventService.grantRewardsToUser`)

- Parâmetro obrigatório `eventId`
- `canActAsEventCoordinator` antes da transação
- `runTransaction`: payout + crédito em `users`
- Campo `_liveEventRewardEventId` em `users` para validação das rules (auditoria; leitura restrita por S1)

**UX:** inalterada — host/admin encerra evento; XP continua automático ao final.

---

## Deploy

```bash
firebase deploy --only firestore:rules
```

Publicar app com `LiveEventService` atualizado **junto** das rules (transação exige payout na mesma transação).

---

## Rollback

### 1. Rules (`users` + `live_events`)

Restaurar bloco anterior:

```javascript
function isLiveEventRewardGrant() {
  return request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['xp', 'badges', 'updatedAt']);
}

// users update:
|| (isSignedIn() && isLiveEventRewardGrant())

// Remover match reward_payouts e isLiveEventRewardGrantToUser / isLiveEventCoordinatorForEvent
```

### 2. App

Reverter `grantRewardsToUser` para `set` direto em `users` sem `eventId`/transação.

### 3. Dados

Documentos `reward_payouts` podem permanecer (somente leitura); não afetam rollback funcional.

---

## Checklist de testes

### Fluxo normal (host)

- [ ] Criar evento como admin; iniciar como host
- [ ] 2+ jogadores participam e respondem
- [ ] Host encerra evento (play ou dashboard)
- [ ] Participantes têm `xpEarned` em `participants`
- [ ] `users/{uid}` de cada participante incrementa `xp`
- [ ] Existe `live_events/{id}/reward_payouts/{uid}` com `grantedBy` = host

### Fluxo admin

- [ ] Admin encerra evento em evento sem host legado
- [ ] Recompensas aplicadas; `grantedBy` = admin uid

### Segurança (D2)

- [ ] Conta aluno A tenta `set` em `users/B` com `{xp: increment}` → **permission-denied**
- [ ] Aluno A tenta criar `reward_payouts` em evento alheio → **permission-denied**
- [ ] Host do evento X **não** aplica payout em evento Y (rules `eventId`)

### Regressão

- [ ] Inscrição / join counters OK
- [ ] Avanço de rodadas só host/admin (Fase B)
- [ ] S1: aluno não lê perfil privado de outro
- [ ] UI play/dashboard sem mudanças visíveis

---

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `firestore.rules` | D2: `reward_payouts`, `isLiveEventRewardGrantToUser`, remove grant amplo |
| `lib/services/live_event_service.dart` | Transação payout + `grantRewardsToUser(eventId: ...)` |
| `docs/LIVE_EVENTS_D2_PRE_REPORT.md` | Pré-relatório |
| `docs/LIVE_EVENTS_D2.md` | Este documento |

---

## Critérios de aceite

- [x] Apenas host/admin concede recompensas em `users` de terceiros
- [x] Fim de evento mantém crédito automático de XP
- [x] Sem alteração de UX
- [x] Vetor D2 da auditoria fechado
