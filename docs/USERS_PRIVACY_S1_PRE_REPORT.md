# Relatório prévio — S1 (Privacidade dos usuários)

**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `ADMIN_UNIFICATION.md`, `ARCHITECTURE.md`  
**Data:** 2026-05-19  
**Release:** R-E (Privacy) — item S1

---

## Problema (auditoria)

`users/{userId}` com `allow read: if isSignedIn()` expõe a **qualquer usuário logado**:

- e-mail, telefone, cidade  
- `isAdmin`, `rbacRoles`  
- `xp`, `badges`, `oscePerformance`  

Risco **P0** (privacidade e enumeração de contas admin).

---

## Mapeamento de leituras `users` (código)

| Arquivo | Operação | Alvo | Quebra com S1? |
|---------|----------|------|----------------|
| `home_page.dart` | stream doc | `users/{widget.userId}` | Não (próprio) |
| `HomeDashboardPage` | stream doc | próprio | Não |
| `perfil_page.dart` | stream/set | próprio | Não |
| `tela_flashcards.dart` | sub `progresso` | próprio | Não |
| `cronograma_service.dart` | sub cronograma | próprio | Não |
| `questao_service.dart` | sub `progresso_questoes` | próprio | Não |
| `simulado_service.dart` | sub `simulados_historico` | próprio | Não |
| `user_profile_service.dart` | merge doc | próprio | Não |
| `rbac_service.dart` | get doc | próprio (contexto) | Não |
| `admin_auth_service.dart` | get/set | outro uid (grant/revoke) | Não — `isAppAdmin()` |
| `admin_legacy_compat.dart` | get/set | outro uid (RBAC sync) | Não — admin |
| `master_admin_users_page.dart` | query `.limit(100)` | todos | Não — `isAppAdmin()` |
| `firestore_platform_repositories.dart` | count/where | agregados admin | Não — `isAppAdmin()` |
| `global_message_service.dart` | doc | próprio | Não |
| `live_event_service.dart` | set merge | **outro** uid (XP) | Não — regra de **write** dedicada |
| OSCE / Live play | — | nomes em `participants` | Não lê `users` de terceiros |

**Conclusão:** Nenhuma tela de aluno lê `users/{outroUid}` hoje. S1 pode ser aplicado nas **rules** com risco baixo de regressão em fluxos críticos.

---

## Modelo de dados (3 camadas)

| Camada | Caminho | Conteúdo | Leitura |
|--------|---------|----------|---------|
| **Privado** | `users/{uid}` | e-mail, nome, telefone, cidade, flags admin, RBAC, XP, badges, desempenho | Dono + `isAppAdmin()` |
| **Público** | `users/{uid}/public_profile/profile` | `displayName`, `photoUrl` | Qualquer `isSignedIn()` |
| **Administrativo** | `users` (query/agregados) | Painel Mestre, dashboard | `isAppAdmin()` |

Nomes em salas OSCE / Live Events continuam em `participants.displayName` (sem mudança de UX).

---

## Escritas cruzadas (compatibilidade)

| Fluxo | Escrita em `users/{outro}` | Tratamento S1 |
|-------|---------------------------|---------------|
| Live Events — `grantRewardsToUser` | `xp`, `badges` | `isLiveEventRewardGrant()` |
| OSCE — `oscePerformance` (legado) | campo único | `isOscePerformanceOnlyUpdate()` (mantido) |
| Admin — `grantAdmin` / RBAC | vários campos | `isAppAdmin()` |

Não alterar código de Live Events / OSCE / simulados / flashcards.

---

## Plano de implementação

1. `firestore.rules` — read restrito; subcoleções com `isAppAdmin()`; bloco `public_profile`  
2. `UserPublicProfileService` — sync não destrutivo de campos públicos  
3. `UserProfileService` + `perfil_page` — sync ao salvar (sem mudança de UI)  
4. `FirestorePaths.userPublicProfile`  
5. Documentação + checklist + rollback  

---

## Rollback

Reverter bloco `match /users/{userId}` para:

```javascript
allow read: if isSignedIn();
```

e subcoleções para `isOwner(userId) || isAdmin()`.

Deploy: `firebase deploy --only firestore:rules`

---

## Critérios de aceite

- [ ] Aluno A não lê `users/{uidB}` (console / regras simulator)  
- [ ] Aluno lê próprio perfil, progresso, cronograma  
- [ ] Admin / Painel Mestre listam usuários  
- [ ] Live Events ainda concedem XP ao encerrar  
- [ ] Login, home, flashcards, questões, OSCE lobby inalterados  
