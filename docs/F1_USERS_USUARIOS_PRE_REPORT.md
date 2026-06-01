# Relatório prévio — F1 (Unificação `users` vs `usuarios`)

**Referências:** `TECHNICAL_AUDIT.md`, `P0_MIGRATION_PLAN.md`, `USERS_PRIVACY_S1.md`, `ARCHITECTURE.md`  
**Data:** 2026-05-19

---

## Fase 1 — Auditoria

### Coleção oficial vs legada

| | `users` | `usuarios` |
|---|---------|------------|
| **Papel** | Fonte oficial (perfil, RBAC, progresso, subcoleções) | Legada — progresso flashcards antigo |
| **Rules atuais** | S1: read dono/admin; subcoleções dono/admin | read/write dono ou admin |
| **App ativo** | Sim — todo fluxo de estudo | Não — só código morto |

### Leituras `users` (ativas)

| Arquivo | Uso |
|---------|-----|
| `home_page.dart` | Perfil + `users/{uid}/progresso` (dashboard) |
| `perfil_page.dart` | Perfil |
| `tela_flashcards.dart` | `progresso` + resumo no doc raiz |
| `cronograma_service.dart` / `cronograma_page.dart` | Cronograma + `progresso` |
| `questao_service.dart` | `progresso_questoes` |
| `simulado_service.dart` | `simulados_historico`, `progresso_questoes` |
| `user_profile_service.dart` | ensure documento |
| `user_public_profile_service.dart` | `public_profile` |
| `admin_auth_service.dart`, `admin_legacy_compat.dart`, `rbac_service.dart` | Admin/RBAC |
| `global_message_service.dart` | Flags de mensagem global |
| `live_event_service.dart` | XP/badges (write) |
| `master_admin_users_page.dart`, `firestore_platform_repositories.dart` | Admin |

### Escritas `users` (ativas)

Mesmos fluxos acima; progresso flashcards grava em `users/{uid}/progresso/{cardId}` com schema atual (`nivel`, `proximaRevisao`, etc.).

### Leituras `usuarios`

| Arquivo | Status |
|---------|--------|
| `lib/services/progresso_service.dart` | **Morto** — zero imports no projeto |

### Escritas `usuarios`

| Arquivo | Status |
|---------|--------|
| `lib/services/progresso_service.dart` | **Morto** — `salvarResposta` nunca chamado |

### Dados esperados por coleção

| Coleção | Estrutura | Schema progresso |
|---------|-----------|------------------|
| `users/{uid}` | Doc perfil + subcoleções | `progresso/{cardId}`: `nivel`, `proximaRevisao`, `dificuldade`, … |
| `usuarios/{uid}/progresso/{cardId}` | Legado | `acertos`, `erros`, `ultima_revisao` (formato antigo) |

### Conclusão da auditoria

- **Funcionalidades ativas** dependem apenas de `users`.
- **`usuarios`** é dívida técnica + possíveis dados históricos em produção.
- **Risco F1:** usuários antigos com progresso só em `usuarios` não veem cards estudados até migração.

---

## Fase 2 — Estratégia

1. **Oficial:** `users` (inalterado para fluxos ativos).
2. **Legado:** `usuarios` — somente leitura nas rules; sem novas escritas pelo app.
3. **Migração:** `UserProgressMigrationService` — merge idempotente `usuarios/.../progresso` → `users/.../progresso` se doc destino não existir; **não apaga** origem.
4. **Gatilho:** `UserProfileService.ensureUserDocument` (pós-login, não bloqueante).
5. **`ProgressoService`:** redirecionar para `users`; marcar `@Deprecated`; manter API para não remover funcionalidade.
6. **Validação:** script `tool/f1_validate_usuarios_refs.dart` + allowlist documentada.

**Fora de escopo (requisito explícito):** alterar UX/login/flashcards/simulados/OSCE/Live/Painel Mestre; apagar coleção `usuarios`.

---

## Fase 3–4 — Implementação prevista

| Entregável | Função |
|------------|--------|
| `user_progress_migration_service.dart` | Cópia segura legado → users |
| `progresso_service.dart` | Escrita/leitura só em `users` |
| `firestore.rules` | `usuarios` read-only |
| `FirestorePaths` | Constantes subcoleção + deprecação `usuarios` |
| `tool/f1_validate_usuarios_refs.dart` | CI/local: detecta referências proibidas |

---

## Riscos e mitigação

| Risco | Mitigação |
|-------|-----------|
| Perda de progresso | Merge só se destino vazio; backup Fase 0 |
| Schema legado incompatível com cronograma | Docs copiados com `_migratedFrom`; usuário reestuda card se faltar `proximaRevisao` |
| Rules bloqueiam migração | Leitura `usuarios` permitida ao dono |

---

## Rollback

1. Reverter rules `usuarios` para `read, write: if isOwner \|\| isAdmin()`.
2. Remover chamada de migração em `UserProfileService`.
3. Restaurar `ProgressoService` anterior se necessário.
4. Dados em `users` migrados permanecem (não destrutivo).

---

## Critérios de aceite

- [ ] Zero escritas app em `usuarios`
- [ ] `ProgressoService` usa `users`
- [ ] Migração idempotente no login
- [ ] Validador documentado
- [ ] Coleção `usuarios` intacta no Firestore
