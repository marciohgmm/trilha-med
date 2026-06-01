# S1 — Privacidade da coleção `users`

**Status:** Implementado  
**Pré-relatório:** `docs/USERS_PRIVACY_S1_PRE_REPORT.md`  
**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `ADMIN_UNIFICATION.md`, `ARCHITECTURE.md`

---

## Objetivo

Impedir que usuários comuns leiam dados privados de outros usuários, mantendo admins operacionais e fluxos atuais (OSCE, Live Events, estudo) sem mudança de UX.

---

## Modelo de três camadas

| Camada | Firestore | Campos típicos | Quem lê |
|--------|-----------|----------------|---------|
| **Privado** | `users/{uid}` | `email`, `nome`, `telefone`, `cidade`, `isAdmin`, `rbacRoles`, `xp`, `badges`, `oscePerformance` | Dono (`uid == auth`) ou `isAppAdmin()` |
| **Público** | `users/{uid}/public_profile/profile` | `displayName`, `photoUrl`, `updatedAt` | Qualquer usuário autenticado |
| **Administrativo** | `users` (queries, count) | Agregados Painel Mestre | `isAppAdmin()` |

**Onde buscar nomes de terceiros hoje:** `osce_rooms/.../participants`, `live_events/.../participants` — **não** `users`.

---

## Regras Firestore (`users`)

### Documento raiz

| Operação | Regra |
|----------|--------|
| read | `isOwner(userId) \|\| isAppAdmin()` |
| create | `isOwner(userId)` |
| update | dono, `isAppAdmin()`, `isOscePerformanceOnlyUpdate()`, `isLiveEventRewardGrant()` |
| delete | `isAppAdmin()` |

### `public_profile/{profileId}`

| Operação | Regra |
|----------|--------|
| read | `isSignedIn()` |
| create/update | `isOwner(userId)` |
| delete | dono ou `isAppAdmin()` |

### Subcoleções (`progresso`, `progresso_questoes`, …)

| Operação | Regra |
|----------|--------|
| read/write | `isOwner(userId) \|\| isAppAdmin()` |

`isAppAdmin()` = founder + `admins/{uid}` + `users.isAdmin` (ver `ADMIN_UNIFICATION.md`).

---

## Cliente

| Componente | Função |
|------------|--------|
| `UserPublicProfileService` | Sync merge em `public_profile/profile` |
| `UserProfileService.ensureUserDocument` | Sync público após login (não bloqueia se falhar) |
| `PerfilPage` | Sync `displayName` ao salvar nome (mesma tela, sem UX nova) |

**Não alterados:** login UI, flashcards, questões, simulados, OSCE, Live Events (apenas regra de write para XP).

---

## Mapeamento de leituras (auditoria)

Todas as leituras de `users` no app usam `users/{uid}` do **próprio** usuário, exceto:

- Painel Mestre / dashboard admin (`isAppAdmin`)
- `grantAdmin` / RBAC sync (admin)

Nenhuma correção obrigatória em telas de aluno.

---

## Deploy

```bash
firebase deploy --only firestore:rules
```

Publicar app após rules (sync de `public_profile` é opcional e incremental).

---

## Rollback

1. Restaurar em `firestore.rules`:

```javascript
match /users/{userId} {
  allow read: if isSignedIn();
  allow create: if isOwner(userId);
  allow update: if isOwner(userId) || isAdmin() || isFounder()
    || (isSignedIn() && isOscePerformanceOnlyUpdate());
  allow delete: if isAdmin();
  match /{subcollection}/{docId} {
    allow read, write: if isOwner(userId) || isAdmin();
  }
}
```

2. `firebase deploy --only firestore:rules`

O app continua funcionando; perfis públicos ficam órfãos (inofensivo).

---

## Checklist de testes

### Privacidade (rules / console)

- [ ] Usuário A autenticado **não** lê `users/{uidB}` (permission-denied)
- [ ] Usuário A lê `users/{uidA}` com sucesso
- [ ] Usuário A lê `users/{uidB}/public_profile/profile` com sucesso (se existir)

### Fluxos aluno (sem mudança de UX)

- [ ] Login e home carregam nome
- [ ] Perfil: salvar nome/telefone/cidade
- [ ] Flashcards e progresso
- [ ] Questões e simulado
- [ ] Cronograma
- [ ] OSCE lobby e estação (nomes na lista de participantes)
- [ ] Live Events — inscrição e jogo

### Admin

- [ ] Painel Mestre → módulo Usuários lista contas
- [ ] Dashboard admin (contagens) sem erro
- [ ] `grantAdmin` / `revokeAdmin` funcionam

### Live Events (write cruzado)

- [ ] Encerrar evento concede XP — sem `permission-denied` em `users/{participante}`

### Perfil público

- [ ] Após login, doc `public_profile/profile` criado/atualizado (opcional verificar no console)
- [ ] Após editar nome no perfil, `displayName` público atualizado

---

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `firestore.rules` | S1 read/write + `public_profile` + `isLiveEventRewardGrant` |
| `lib/core/constants/firestore_paths.dart` | Constantes `public_profile` |
| `lib/models/user_public_profile.dart` | Modelo público |
| `lib/services/auth/user_public_profile_service.dart` | Serviço de sync |
| `lib/services/auth/user_profile_service.dart` | Sync no ensure |
| `lib/screens/perfil_page.dart` | Sync ao salvar |
| `docs/USERS_PRIVACY_S1_PRE_REPORT.md` | Relatório prévio |
| `docs/USERS_PRIVACY_S1.md` | Este documento |

**Não alterados:** `login_page.dart`, `main.dart`, serviços OSCE/Live/questões/flashcards (lógica), UX das telas.

---

## Próximos passos (opcional)

- Migrar telas que no futuro exibirem nome de terceiro para `UserPublicProfileService.watchProfile(uid)`
- Backfill `public_profile` para usuários existentes (script admin)
- Restringir `isLiveEventRewardGrant` a host/coordenador via custom claims ou Cloud Function
