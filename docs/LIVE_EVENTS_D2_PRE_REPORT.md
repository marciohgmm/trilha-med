# Relatório prévio — D2 (recompensas Live Events em `users`)

**Referências:** `FINAL_AUDIT_POST_IMPLEMENTATION.md` (D2), `USERS_PRIVACY_S1.md`, `LIVE_EVENTS_PHASE_B.md`  
**Data:** 2026-05-19

---

## Problema (D2)

Regra atual em `users/{uid}`:

```javascript
allow update: ... || (isSignedIn() && isLiveEventRewardGrant());
```

`isLiveEventRewardGrant()` valida apenas campos `xp`, `badges`, `updatedAt`. **Qualquer** usuário autenticado pode incrementar XP/badge de **qualquer** `users/{outroUid}`.

## Fluxo legítimo hoje

1. Host ou admin executa `endEvent` → `_finalizeRankings`
2. Para cada participante: `grantRewardsToUser(userId, xp, badgeId)`
3. Escrita merge em `users/{userId}` com `FieldValue.increment`

O ator Firestore é o **host/admin** (`request.auth.uid`), não o beneficiário.

## Estratégia (sem mudar UX)

| Camada | Ação |
|--------|------|
| **Firestore** | Subcoleção `live_events/{eventId}/reward_payouts/{userId}` — create só coordenador do evento |
| **Firestore** | Update em `users/{userId}` com XP só se existir payout correspondente **e** `grantedBy == auth.uid` **e** coordenador do `eventId` |
| **App** | `grantRewardsToUser` em **transação**: cria payout + atualiza `users` (campo auditoria `_liveEventRewardEventId`) |
| **App** | Guarda cliente `canActAsEventCoordinator` antes da transação |

Remover `isSignedIn() && isLiveEventRewardGrant()` amplo.

## Vetores eliminados

| Ataque | Após correção |
|--------|----------------|
| Aluno A grava XP em `users/B` | Negado — sem payout + não é coordenador |
| Aluno A cria payout falso | Negado — create só coordenador |
| Host concede após evento alheio | Negado — `isLiveEventCoordinatorForEvent(eventId)` |

## Riscos / mitigação

| Risco | Mitigação |
|-------|-----------|
| Transação falha após payout | Payout fica órfão; reprocesso manual ou script admin |
| Campo `_liveEventRewardEventId` em `users` | Somente leitura owner/admin (S1); rastro de auditoria |
| Eventos sem `hostId` | Só admin coordena (já Fase B) |

## Rollback (resumo)

Reverter rules + `grantRewardsToUser` sem transação/payout — ver doc final.

## Critérios de aceite

- [ ] Host encerra evento → participantes recebem XP
- [ ] Conta comum não altera `users/{outro}` com xp/badges
- [ ] Admin dashboard `endEvent` OK
- [ ] Sem mudança de UI
