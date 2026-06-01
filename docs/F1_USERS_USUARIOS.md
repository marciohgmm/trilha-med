# F1 — Unificação `users` vs `usuarios`

**Status:** Implementado  
**Pré-relatório:** `docs/F1_USERS_USUARIOS_PRE_REPORT.md`

---

## Resumo

| Coleção | Papel após F1 |
|---------|----------------|
| **`users`** | Única fonte oficial (perfil, progresso, questões, admin) |
| **`usuarios`** | Legada — somente leitura nas rules; dados preservados |

O app **ativo** já usava `users` para flashcards, cronograma, home e questões. F1 elimina a dependência funcional restante (`ProgressoService` morto), adiciona migração automática não destrutiva e validação.

---

## Fase 1 — Auditoria (resultado)

### Referências a `usuarios` no código

| Arquivo | Tipo | Ativo? |
|---------|------|--------|
| `progresso_service.dart` | escrita legada | Redirecionado para `users` |
| `user_progress_migration_service.dart` | leitura migração | Sim (login) |
| `firestore_paths.dart` | constante `@Deprecated` | Documentação |

### Referências a `users` (amostra — todas ativas)

`home_page`, `perfil_page`, `tela_flashcards`, `cronograma_*`, `questao_service`, `simulado_service`, auth/RBAC, live events (XP), Painel Mestre.

### Dados

| Path | Conteúdo típico |
|------|-----------------|
| `users/{uid}` | email, nome, isAdmin, rbacRoles, xp |
| `users/{uid}/progresso/{cardId}` | nivel, proximaRevisao, dificuldade |
| `users/{uid}/progresso_questoes` | respostas questões |
| `usuarios/{uid}/progresso/{cardId}` | **legado:** acertos, erros, ultima_revisao |

---

## Fase 2 — Estratégia aplicada

1. Oficial = `users`  
2. Migração merge-on-miss no login  
3. Rules: `usuarios` read-only  
4. `ProgressoService` → apenas `users` (API preservada, `@Deprecated`)  
5. Validador `tool/f1_validate_usuarios_refs.dart`

---

## Fase 3 — Implementação

### `UserProgressMigrationService`

- Lê `usuarios/{uid}/progresso/*`
- Para cada card: se **não** existe `users/{uid}/progresso/{cardId}`, copia com merge
- Metadados: `_migratedFrom: usuarios`, `migratedAt`
- **Não** apaga `usuarios`

### `UserProfileService.ensureUserDocument`

Chama migração após login (try/catch — não bloqueia).

### `ProgressoService`

- Path: `users` + `FirestorePaths.userProgressSubcollection`
- `@Deprecated` — funcionalidade mantida

### `FirestorePaths`

- `userProgressSubcollection`, `userProgressoQuestoesSubcollection`, …
- `usuarios` marcado `@Deprecated`

### `firestore.rules`

```text
usuarios: allow read (owner | appAdmin); allow write: false
```

---

## Fase 4 — Validação

```bash
dart run tool/f1_validate_usuarios_refs.dart
```

**Allowlist** (referências permitidas a string `usuarios`):

- `lib/core/constants/firestore_paths.dart`
- `lib/services/user_progress_migration_service.dart`
- `lib/services/progresso_service.dart`
- `tool/f1_validate_usuarios_refs.dart`

---

## Referências

### Removidas / redirecionadas

| Antes | Depois |
|-------|--------|
| `ProgressoService` → `usuarios/.../progresso` | `users/.../progresso` |
| Rules `usuarios` write aberto | write `false` |

### Ainda existentes (intencional)

| Referência | Motivo |
|------------|--------|
| `FirestorePaths.usuarios` | Constante legada `@Deprecated` |
| `UserProgressMigrationService` | Leitura única para migração |
| `firestore.rules` `match /usuarios` | Leitura legada |
| Dados no Firestore `usuarios/**` | Não apagados |

---

## Deploy

```bash
firebase deploy --only firestore:rules
dart run tool/f1_validate_usuarios_refs.dart
```

Publicar app com migração no login.

---

## Rollback

1. Rules `usuarios`: restaurar `allow read, write: if isOwner(userId) || isAdmin();`
2. Remover bloco de migração em `user_profile_service.dart`
3. Reverter `progresso_service.dart` se necessário

Dados copiados para `users` permanecem.

---

## Checklist de testes

### Progresso flashcards

- [ ] Estudar card — grava em `users/{uid}/progresso`
- [ ] Home dashboard % concluído correto
- [ ] Cronograma revisões do dia

### Migração legada (staging)

- [ ] Criar doc em `usuarios/{uid}/progresso/testCard` (console)
- [ ] Login — doc aparece em `users/.../progresso/testCard` com `_migratedFrom`
- [ ] Segundo login — idempotente (não duplica)
- [ ] Doc original em `usuarios` ainda existe

### Rules

- [ ] App **não** consegue `set` em `usuarios` (permission-denied)
- [ ] Dono ainda **lê** `usuarios` (migração)

### Regressão (inalterados)

- [ ] Login / registro
- [ ] Questões e simulado
- [ ] OSCE lobby
- [ ] Live Events
- [ ] Painel Mestre usuários
- [ ] Perfil privado (S1)

### Validador

- [ ] `dart run tool/f1_validate_usuarios_refs.dart` → exit 0

---

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `lib/services/user_progress_migration_service.dart` | **Novo** — migração F1 |
| `lib/services/progresso_service.dart` | Path `users` + `@Deprecated` |
| `lib/core/constants/firestore_paths.dart` | Subcoleções + deprecação |
| `lib/services/auth/user_profile_service.dart` | Gatilho migração |
| `firestore.rules` | `usuarios` read-only |
| `tool/f1_validate_usuarios_refs.dart` | **Novo** — validador |
| `docs/F1_USERS_USUARIOS_PRE_REPORT.md` | Pré-relatório |
| `docs/F1_USERS_USUARIOS.md` | Este documento |

**Não alterados (requisito):** `tela_flashcards.dart`, `login_page.dart`, OSCE, Live Events, Painel Mestre UI, simulados.

---

## Critérios de aceite (P0 F1)

- [x] Zero escritas funcionais em `usuarios` pelo app  
- [x] Progresso unificado em `users`  
- [x] Inventário documentado  
- [x] Coleção `usuarios` não removida  
- [x] Fallback migração no login  
