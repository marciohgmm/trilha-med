# Relatório prévio — Release R-B (OSCE): V2, S3, S2

**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `ARCHITECTURE.md`  
**Data:** 2026-05-19  
**Status:** Pré-implementação

---

## Contexto (auditoria)

| ID | Achado | Risco |
|----|--------|-------|
| **V2** | `streamAllOpenRooms()` escuta **toda** `osce_rooms` e filtra em memória | Custo/leitura cresce linearmente com salas |
| **S3** | `osce_meta` — `allow write: if isSignedIn()` | Qualquer usuário pode alterar contadores globais |
| **S2** | `osce_rooms` — `allow update, delete: if isSignedIn()` | Qualquer usuário pode alterar/apagar salas alheias |

OSCE permanece em `lib/services/osce/*` (arquitetura legada, `ARCHITECTURE.md` §8). Sem Cloud Functions no repositório — regras e cliente devem refletir escritas reais.

---

## Escopo desta release

| Incluído | Excluído (explícito) |
|----------|----------------------|
| V2 — query filtrada + índice | UX do lobby/estação |
| S3 — regras `osce_meta` | Avaliação, scoring, rubrica |
| S2 — regras `osce_rooms` + participantes | V1 questões, S1 users, S4 live |
| Compatibilidade fluxos atuais | Remoção de coleções legadas |
| Retry alocação de sala (V3 mínimo) | Cloud Function para contador |

---

## V2 — Lobby (análise)

**Hoje:** `OsceRoomService.streamAllOpenRooms()` → `_roomsCol.snapshots()` → exclui `ended` e `evaluating` em Dart.

**Problema:** Salas `evaluating` são excluídas do lobby (comportamento atual preservado). Salas `ended` idem.

**Solução:**

```text
where status in [waiting, selectingCase, ready, running]
orderBy roomNumber
```

`evaluating` **não** entra no lobby (igual ao filtro atual). Índice composto: `status` + `roomNumber` em `firestore.indexes.json`.

**Risco:** Índice ausente → erro `failed-precondition` no lobby. **Mitigação:** deploy índices **antes** do app (Fase 0.2 do P0).

---

## S3 — `osce_meta` (análise)

**Hoje:** Transação em `osce_meta/counters` (`lastRoomNumber++`) no `createRoom`; fallback faz `_roomsCol.get()` (V3 — fora do escopo R-B principal, mas incompatível com S3 estrito).

**Escritas legítimas do cliente:**

| Operação | Campos | Quem |
|----------|--------|------|
| Alocar número de sala | `lastRoomNumber` (+1 ou create) | Usuário autenticado ao criar sala |

**Solução de regras:**

- `read`: `isSignedIn()` (inalterado)
- `create` / `update`: `isAppAdmin()` **OU** `isOsceMetaCounterWrite()` (apenas incremento monotônico de `lastRoomNumber`)
- `delete`: `isAppAdmin()` apenas

**Compatibilidade:** Criação de sala por aluno continua sem admin; contador não pode ser resetado arbitrariamente.

**Cliente:** Remover fallback full-scan; retry 3× na transação; fallback opcional `orderBy('roomNumber', descending).limit(1)` (não exige permissão em `osce_meta` alheia).

---

## S2 — `osce_rooms` (análise de escritas)

| Método | Campos principais | Ator esperado |
|--------|-------------------|---------------|
| `createRoom` | doc novo, `hostId` | Host |
| `_joinRoom` | `participantCount` +1 | Entrante (antes do doc participant) |
| `leaveRoom` | count −1, papéis, timers, status | Participante que sai |
| `_closeRoomIfEmpty` | `status: ended` | Último a sair |
| `assumeEvaluator` | `evaluatorUserId`, `status`, roles | Participante / novo avaliador |
| `assignEvaluator` | troca avaliador | Avaliador atual |
| `assumeEvaluated` / `assignEvaluated` | `evaluatedUserId`, `doctorUserId` | Médico / avaliador |
| `clearEvaluated` | remove médico | Avaliador |
| `selectCase` | `caseId`, `specialty` | Avaliador (UI) |
| `startStation` | timer, `running`, exams | Médico avaliado |
| `requestExam` / `releaseExam` | `exams.*` | Médico / avaliador |
| `linkEvaluation` / `closeRoomAfterEvaluation` | `evaluating` / `ended` | Fluxo avaliação |
| `participants/*` | create/update | `isOwner(participantId)` |

**Solução de regras (camadas):**

1. **Admin** — `isAppAdmin()` → update/delete total  
2. **Host** — `hostId == auth.uid` → update (exceto troca de `hostId` / `roomNumber`)  
3. **Avaliador / avaliado** — campos conforme `evaluatorUserId` / `evaluatedUserId`  
4. **Join** — update só `participantCount` +1 e `updatedAt`  
5. **Leave / encerrar** — participante existente ou update tipo `ended` com count 0  
6. **Tamper** — negar mudança de `hostId`, `roomNumber`, `createdAt` para não-admin  

**Delete:** apenas `isAppAdmin()` (app não deleta salas no fluxo normal).

**Participantes:** manter `create` owner; `update` owner ou admin; reforçar leitura `isSignedIn()`.

---

## Ordem de deploy (P0)

```text
1. firestore.indexes.json (V2)
2. firebase deploy --only firestore:indexes
3. firestore.rules (S3 + S2)
4. firebase deploy --only firestore:rules
5. Release app (V2 + retry meta)
```

---

## Plano de rollback

| Sintoma | Rollback |
|---------|----------|
| Lobby vazio / erro de índice | Reverter app para `snapshots()` full collection **ou** deploy índice; rules podem ficar |
| `permission-denied` ao criar sala | Reverter regra `osce_meta` para `isSignedIn()` write temporário |
| Multiplayer travado (update sala) | Reverter bloco `osce_rooms` update para `isSignedIn()` |
| Contador duplicado | Corrigir manualmente `osce_meta/counters`; não rollback de app |

**Backup recomendado:** `osce_rooms`, `osce_meta`, export antes do deploy de rules.

---

## Critérios de aceite (R-B)

- [ ] Lobby não usa listener na coleção inteira  
- [ ] Índice `status` + `roomNumber` documentado e deployável  
- [ ] Usuário comum não escreve `osce_meta` arbitrariamente; criar sala OK  
- [ ] Usuário B não altera sala onde não é host/avaliador/médico/participante (join)  
- [ ] Fluxo completo: criar → entrar → papéis → estação → exames → avaliação → sair  
- [ ] UX e scoring inalterados  

---

## Arquivos previstos

| Arquivo | Itens |
|---------|-------|
| `firestore.indexes.json` | V2 |
| `firestore.rules` | S2, S3 |
| `lib/services/osce/osce_room_service.dart` | V2, V3 mínimo |
| `docs/OSCE_RELEASE_RB.md` | Pós-implementação |

**Sem alteração:** `osce_lobby_page.dart`, `osce_station_page.dart`, `osce_evaluation_*`, scoring.
