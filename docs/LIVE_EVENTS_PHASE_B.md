# Live Events — Fase B: Host único (implementado)

**Referências:** `LIVE_EVENTS_ROUND_CONTROL_ANALYSIS.md`, `LIVE_EVENTS_PHASE_B_PLAN.md`  
**Data:** 2026-05-19

---

## Resumo

O criador do evento passa a ser o **host** (`hostId`). Somente **host** ou **administrador** (`isAppAdmin` nas rules / `AdminAuthService` no app) pode:

- `advanceToReveal` / `advanceFromReveal`
- `startEvent` (com atribuição de host em eventos legados)
- `endEvent` / `cancelEvent` / `updateEvent`

Jogadores comuns: **entrar**, **responder** (`submitAnswer`), **visualizar** (streams). O timer na UI continua para todos; **escritas de rodada** só no host/admin.

---

## Modelo de dados

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `hostId` | `string?` | UID Firebase do criador/coordenador |

- Gravado em `createEvent` com o usuário autenticado.
- Eventos antigos sem `hostId`: apenas admin avança no cliente; `startEvent` define `hostId` = quem iniciou.

---

## Camada de aplicação

### `LiveEventService`

| Método | Guarda |
|--------|--------|
| `canActAsEventCoordinator` | Público — host ou admin |
| `advanceToReveal` / `advanceFromReveal` | Retorno silencioso se negado |
| `startEvent` / `endEvent` / `cancelEvent` / `updateEvent` | `StateError` se negado |
| `joinEvent` / `submitAnswer` | Sem guarda de coordenador |
| `createEvent` | Exige usuário logado; define `hostId` |

### `LiveEventPlayPage`

- `_canDriveRounds(event)`: admin **ou** `event.isHost(userId)`
- `Timer` 1 Hz: `setState` para todos; `advanceToReveal` só se `_canDriveRounds`
- Fase `reveal`: `_afterReveal` só se `_canDriveRounds`

### `AdminLiveEventDashboardPage`

- Sem mudança de UI; admin já passa nos guards.

---

## Firestore Security Rules

```text
live_events/{id}
  create: isAppAdmin + hostId == auth.uid
  update: isAppAdmin || isLiveEventHost || joinCountersOnly
  delete: isAppAdmin

live_events/{id}/participants/{uid}
  update: isOwner(uid) || isAppAdmin
```

**Deploy obrigatório** após release do app:

```bash
firebase deploy --only firestore:rules
```

---

## Compatibilidade com eventos existentes

| Situação | Comportamento |
|----------|----------------|
| Sem `hostId`, status `scheduled` | Admin inicia no dashboard → `hostId` = UID do admin |
| Sem `hostId`, já `live` | Só admin avança (dashboard ou play com conta admin) |
| Com `hostId` | Host na play page + admin no dashboard |

---

## Plano futuro — Cloud Functions (Fase D)

Objetivo: motor de rodadas **no servidor**, cliente somente leitura no doc do evento.

| Etapa | Entrega |
|-------|---------|
| D1 | `functions/src/live_events/advanceToReveal.ts` — scheduled ou trigger por `endsAt` |
| D2 | `functions/src/live_events/advanceFromReveal.ts` — callable ou task chain pós-reveal |
| D3 | Portar `_eliminateOrLifeBatch`, `_sortearQuestao`, `_finalizeRankings` |
| D4 | Rules: `live_events` `update: if false` para clientes; manter join via Function ou contadores isolados |
| D5 | Cliente remove timers de avanço; mantém `submitAnswer` |

**Benefícios:** anti-cheat, custo O(1) writes/rodada, host offline não trava se usar Scheduler.

**Estimativa:** 1–2 semanas após Fase B estável em produção.

---

## Checklist de testes

### Preparação

- [ ] Deploy rules `firestore.rules`
- [ ] Conta **admin** (founder ou `admins` / `isAdmin`)
- [ ] Conta **aluno A** e **aluno B**
- [ ] Evento novo criado pelo admin (tem `hostId`)

### Criação e host

- [ ] Criar evento no admin → documento contém `hostId` = UID do criador
- [ ] Aluno tenta `createEvent` via SDK → negado pelas rules

### Início e rodadas (host)

- [ ] Admin inicia evento no dashboard
- [ ] Host abre `LiveEventPlayPage` → rodadas avançam no tempo
- [ ] Aluno B na play page → vê timer/contagem mas evento avança (stream)
- [ ] Aluno B **não** gera writes de `currentRound` (verificar no console Firestore / debug)

### Participação

- [ ] Aluno entra (`joinEvent`) → `participantCount` incrementa
- [ ] Aluno responde → só `participants/{uid}` alterado
- [ ] Aluno não altera `participants/{outroUid}` (rules)

### Admin override

- [ ] Admin (não host) usa “Forçar revelação” / “Próxima rodada” → funciona
- [ ] Admin finaliza / cancela → funciona

### Legado sem hostId

- [ ] Evento antigo sem `hostId`: aluno na play **não** avança
- [ ] Admin inicia ou avança pelo dashboard
- [ ] Após `startEvent`, doc ganha `hostId`

### Regressão

- [ ] Pontuação / eliminação / vidas inalteradas
- [ ] XP ao encerrar (`grantRewardsToUser`) inalterado
- [ ] Cards na home listam eventos
- [ ] Tela eliminado / espectador funciona

### Segurança (opcional, console)

- [ ] Simulador rules: aluno `update` em `live_events` com `status` → **deny**
- [ ] Host `update` em `currentRound` → **allow**
- [ ] Aluno `update` só `participantCount` no join → **allow**

---

## Arquivos alterados nesta fase

| Arquivo |
|---------|
| `lib/models/live_event_models.dart` |
| `lib/services/live_event_service.dart` |
| `lib/screens/live_events/live_event_play_page.dart` |
| `firestore.rules` |
| `docs/LIVE_EVENTS_PHASE_B_PLAN.md` |
| `docs/LIVE_EVENTS_PHASE_B.md` |

---

## Rollback

1. Reverter `firestore.rules` para versão anterior (Console).
2. Release app anterior (play page voltaria a N escritores).
3. Campo `hostId` em documentos é inofensivo se app antigo ignorar.
