# Release R-B — OSCE (V2, S3, S2)

**Status:** Implementado  
**Pré-relatório:** `docs/OSCE_RELEASE_RB_PRE_REPORT.md`  
**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `ARCHITECTURE.md`

---

## Resumo

| Item | Problema | Solução |
|------|----------|---------|
| **V2** | Lobby escutava toda `osce_rooms` | Query `status in (...)` + `orderBy roomNumber` + índice composto |
| **S3** | Qualquer usuário escrevia `osce_meta` | Write só admin ou incremento monotônico de `lastRoomNumber` |
| **S2** | Qualquer usuário atualizava/apagava salas | Update por host / avaliador / médico / join / leave / papéis; delete só admin |

**Inalterado:** UX lobby/estação, fluxo aluno, avaliação, scoring, pontuação.

---

## V2 — Lobby otimizado

### Cliente (`OsceRoomService.streamAllOpenRooms`)

```dart
where status in [waiting, selectingCase, ready, running]
orderBy roomNumber
```

Comportamento alinhado ao filtro legado em memória: **não** lista salas `evaluating` nem `ended`.

### Índice Firestore

`firestore.indexes.json`:

- Coleção: `osce_rooms`
- Campos: `status` (ASC), `roomNumber` (ASC)

### Deploy obrigatório

```bash
firebase deploy --only firestore:indexes
```

Aguardar índice **Enabled** antes de publicar o app com V2.

---

## S3 — Metadados OSCE

### Regras (`osce_meta/{docId}`)

| Operação | Quem |
|----------|------|
| read | `isSignedIn()` |
| create | `isAppAdmin()` ou `isOsceMetaCounterCreate()` |
| update | `isAppAdmin()` ou `isOsceMetaCounterUpdate()` (+1 em `lastRoomNumber`) |
| delete | `isAppAdmin()` |

### Cliente (`_allocateRoomNumber`)

1. Até **3 tentativas** na transação `osce_meta/counters`
2. Fallback: `orderBy('roomNumber', descending).limit(1)` — **sem** `get()` na coleção inteira

---

## S2 — Salas e participantes

### `osce_rooms/{roomId}`

| Operação | Regra |
|----------|--------|
| read | `isSignedIn()` |
| create | `hostId == auth.uid` |
| update | Admin, host, avaliador, médico, join (+1 count), leave (−1 count), encerrar vazia, auto-atribuição de papel |
| delete | `isAppAdmin()` |

Campos protegidos em updates não-admin: `hostId`, `roomNumber`, `createdAt`.

### `participants/{participantId}`

| Operação | Regra |
|----------|--------|
| create | Dono do documento |
| update | Dono, admin, host/avaliador (só campo `role`), handoff avaliador/médico |
| delete | Dono ou admin |

---

## Ordem de deploy (produção)

1. Backup: `osce_rooms`, `osce_meta`
2. `firebase deploy --only firestore:indexes`
3. Aguardar índice composto ativo
4. `firebase deploy --only firestore:rules`
5. Publicar app com `OsceRoomService` atualizado

---

## Plano de rollback

| Sintoma | Ação |
|---------|------|
| Lobby com erro `failed-precondition` / índice | Deploy índices; ou reverter app para listener full-collection temporário |
| `permission-denied` ao **criar** sala | Reverter bloco `osce_meta` em `firestore.rules` para `allow write: if isSignedIn()` |
| Multiplayer travado | Reverter bloco `osce_rooms` update para `allow update: if isSignedIn()` |
| Números de sala duplicados | Ajustar manualmente `osce_meta/counters.lastRoomNumber` |

**Reverter rules (trecho legado):**

```javascript
match /osce_meta/{docId} {
  allow read: if isSignedIn();
  allow write: if isSignedIn();
}
match /osce_rooms/{roomId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.resource.data.hostId == request.auth.uid;
  allow update, delete: if isSignedIn();
}
```

---

## Checklist de testes

### V2 — Lobby

- [ ] Lobby carrega sem erro com 0 salas
- [ ] Salas `waiting` / `ready` / `running` aparecem na lista
- [ ] Salas `ended` **não** aparecem
- [ ] Salas `evaluating` **não** aparecem (igual antes)
- [ ] Ordenação por `roomNumber` mantida
- [ ] Entrar em sala pública e privada (código) inalterado

### S3 — Meta

- [ ] Criar sala pública como aluno comum — sucesso
- [ ] Criar sala privada — código gerado
- [ ] `lastRoomNumber` incrementa em `osce_meta/counters`
- [ ] (Manual) Tentativa de `set` arbitrário em `osce_meta` com conta aluno — **negado**

### S2 — Salas

- [ ] Usuário B **não** altera `status` da sala de A (teste manual / console)
- [ ] Host cria sala
- [ ] Segundo usuário entra (contador +1)
- [ ] Assumir avaliador / médico
- [ ] Designar papéis pelo menu do avaliador
- [ ] Selecionar caso, iniciar estação, liberar exames
- [ ] Encerrar estação → avaliação → sala `ended`
- [ ] Sair da sala / sala vazia encerra
- [ ] Admin ainda pode moderar (se aplicável)

### Regressão

- [ ] Login e home inalterados
- [ ] Histórico/avaliação OSCE e notas **sem** mudança de comportamento
- [ ] Casos clínicos admin (`osce_cases`) inalterados

---

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `firestore.rules` | S2 (`osce_rooms`, `participants`), S3 (`osce_meta`) |
| `firestore.indexes.json` | Índice V2 `status` + `roomNumber` |
| `lib/services/osce/osce_room_service.dart` | V2 query; S3 retry + fallback limitado |
| `docs/OSCE_RELEASE_RB_PRE_REPORT.md` | Relatório prévio |
| `docs/OSCE_RELEASE_RB.md` | Este documento |

**Não alterados:** `osce_lobby_page.dart`, `osce_station_page.dart`, `osce_evaluation_service.dart`, `osce_evaluation_scoring.dart`, modelos de avaliação.

---

## Critérios de aceite (P0)

| ID | Status |
|----|--------|
| V2 | Lobby com query filtrada + índice documentado |
| S3 | Meta não editável arbitrariamente; criação de sala OK |
| S2 | Salas protegidas; fluxo host/avaliador/médico/participante preservado |

---

## Próximos passos (fora R-B)

- **V3 completo:** remover fallback `orderBy roomNumber` quando transação for 100% confiável
- **Cloud Function** `allocateOsceRoomNumber` para S3 estrito sem write cliente
- **S1:** restringir leitura de `users` entre alunos
