# Auditoria Técnica — Trilha Med / Revalida Cards

**Data:** 2026-05-19  
**Escopo:** Análise estática do repositório (sem alteração de código).  
**Versão analisada:** branch de trabalho com módulo plataforma, RBAC e Painel Mestre.

---

## Resumo executivo

O projeto opera em **duas camadas arquiteturais paralelas**: serviços legados (`lib/services/*` com Firestore direto) e módulo plataforma (`lib/domain`, `lib/infrastructure`, `PlatformRegistry`). A convivência é intencional, mas gera **fragmentação de dados**, **três mecanismos de admin** e **regras Firestore permissivas** em áreas críticas (OSCE, leitura de `users`, auditoria).

Os riscos mais urgentes são: **segurança** (salas OSCE e metadados editáveis por qualquer usuário autenticado), **dados de progresso espalhados** (`users` vs `usuarios`), e **inconsistência de acesso admin** entre botão oculto na home e `AdminGate`/RBAC.

---

## Legenda

| Campo | Significado |
|-------|-------------|
| **Risco** | Baixo / Médio / Alto |
| **Prioridade** | P0 (urgente) → P3 (backlog) |

---

## 1. Arquitetura

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| A1 | **Dupla arquitetura** — legado (`lib/services`) vs plataforma (`PlatformRegistry`, repositórios). Poucos fluxos de aluno usam a camada nova; RBAC/Painel Mestre sim. | Médio | Definir roadmap: novas features só via `domain` + repositórios; migrar serviços legados por domínio (progresso, questões, OSCE). | Reduz duplicação e bugs de regra de negócio divergente. | P2 |
| A2 | **`lib/core/core.dart` barrel não importado** em lugar nenhum — exports mortos para consumo. | Baixo | Usar barrel nos imports novos ou remover se não for padrão do time. | Organização; sem impacto em runtime. | P3 |
| A3 | **`PlatformUserExtension` e repositório `users`** só existem na infraestrutura; app não usa extensão comercial no perfil. | Baixo | Integrar quando assinaturas forem ligadas ao aluno, ou documentar como “fase 2”. | Evita modelo órfão. | P3 |
| A4 | **Documentação ARCHITECTURE.md desatualizada** — diz que legado não importa `PlatformRegistry`; `RbacService` e Painel Mestre já importam. | Baixo | Atualizar doc com exceções reais (RBAC, master admin). | Alinhamento de equipe. | P3 |
| A5 | **Telas admin de Fase Prática** (`AdminPracticalPhaseListPage`, módulos) existem mas **não há entrada em `AdminPage`**. | Médio | Adicionar card no menu admin ou remover se obsoleto. | Admins conseguem gerenciar modelos sem atalho secreto. | P2 |
| A6 | **“Fase Prática” na home** abre `OsceLobbyPage`, não `PracticalPhaseLandingPage` (landing com módulos publicados). | Médio | Unificar produto: ou rota para landing, ou remover código não referenciado. | UX coerente; menos código morto. | P2 |

---

## 2. Firestore — Coleções e dados

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| F1 | **Coexistência `users` vs `usuarios`** — regras cobrem ambas; app usa quase só `users`, exceto `ProgressoService` → `usuarios/{uid}/progresso`. | **Alto** | Migrar dados de `usuarios` → `users` (script); deprecar coleção; unificar `FirestorePaths` e serviços. | Progresso e estatísticas consistentes; menos confusão em analytics. | **P0** |
| F2 | **Progresso fragmentado em `users/{uid}`** — subcoleções distintas: `progresso` (flashcards), `progresso_questoes`, `simulados_historico`. | Médio | Padronizar nomenclatura e documentar; opcional: agregador de progresso. | Relatórios e backup mais simples. | P2 |
| F3 | **`ProgressoService` é código morto** — nenhum import no projeto; grava em `usuarios`. | Médio | Remover classe ou religar ao fluxo unificado de progresso. | Evita reintrodução acidental do path errado. | P2 |
| F4 | **Campos de papel duplicados** — `rbacRoles`, `roles` (legado), `isAdmin`, coleção `admins`, e-mail founder. | **Alto** | Fonte única: RBAC Firestore + `admins` só como índice; `isAdmin` derivado por Cloud Function ou sync explícito. | Menos admin “fantasma” ou revogado pela metade. | **P0** |
| F5 | **Cache Firestore ilimitado** (`Settings.CACHE_SIZE_UNLIMITED` em `firestore_init.dart`). | Médio | Limitar tamanho (ex.: 100MB) em mobile; monitorar crescimento. | Menor uso de disco em dispositivos antigos. | P2 |

---

## 3. Regras de segurança (Firestore)

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| S1 | **`users/{userId}` — `allow read: if isSignedIn()`** — qualquer usuário logado lê documentos de **todos** os usuários. | **Alto** | Restringir leitura: dono, admin, ou campos públicos em subcoleção `public_profile`. | Privacidade (e-mail, flags admin, RBAC). | **P0** |
| S2 | **`osce_rooms` — `allow update, delete: if isSignedIn()`** — qualquer autenticado pode alterar/apagar salas alheias. | **Alto** | Host + participantes + admin; validar campos em `request.resource`. | Integridade multiplayer OSCE. | **P0** |
| S3 | **`osce_meta` — `allow write: if isSignedIn()`** — contadores manipuláveis. | **Alto** | Apenas Cloud Function ou admin para writes. | Numeração de salas confiável. | **P0** |
| S4 | **`live_events` — `allow update: if isSignedIn()`** — estado do evento alterável por qualquer um. | **Alto** | Admin ou função server-side para transições de estado. | Integridade de eventos ao vivo. | **P0** |
| S5 | **`platform_audit_logs` — `allow create: if isSignedIn()`** — qualquer cliente pode inundar auditoria. | Médio | Criar logs só via Cloud Functions / Admin SDK; client só lê (admin). | Logs confiáveis e custo controlado. | P1 |
| S6 | **`platform_subscriptions` — create pelo próprio `userId`** sem pagamento validado. | Médio | Bloquear create client-side; criar assinatura só após webhook de pagamento. | Evita assinaturas “grátis” fraudulentas. | P1 |
| S7 | **Founder hardcoded** (`marciohgmm@gmail.com`) em rules e Storage — acoplamento e risco operacional. | Médio | Custom claims `founder: true` no Auth; rules usam `request.auth.token.founder`. | Rotação de conta sem deploy de rules. | P2 |
| S8 | **Storage `imagenscard` — `allow read: if true`** — público mundial. | Baixo | OK se intencional; senão signed URLs ou auth. | Custo/bandwidth e conteúdo privado. | P3 |
| S9 | **Três funções admin** (`isAdmin`, `isAppAdmin`, `isOsceCaseEditor`) com critérios ligeiramente diferentes — fácil divergir do app. | Médio | Uma função `isAppAdmin()` única; testes de rules automatizados. | Paridade app ↔ servidor. | P1 |

---

## 4. Índices Firestore

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| I1 | **Dashboard mestre** — contagens com `users.updatedAt` / `createdAt` ≥ 30 dias podem exigir índice composto ou falhar silenciosamente (`_safeCount` → 0). | Médio | Criar índices ou mover métricas para Cloud Function agregada. | KPIs corretos no painel. | P2 |
| I2 | **`platform_subscription_plans`** — `orderBy('sortOrder')` + `where isActive` sem índice explícito em `firestore.indexes.json`. | Médio | Adicionar índice composto se Firestore solicitar. | Lista de planos estável em produção. | P2 |
| I3 | **`platform_audit_logs` — `orderBy('createdAt')`** — índice de campo único geralmente automático; validar em projeto Firebase real. | Baixo | Confirmar no console após deploy. | Evita falha na aba Auditoria. | P3 |
| I4 | **`osce_rooms` — lobby escuta coleção inteira** sem query filtrada — índices não resolvem; é problema de query. | **Alto** | Query `where status in [...]` + índice; paginação. | Custo e latência com muitas salas. | **P0** |

---

## 5. RBAC

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| R1 | **Admin legado vs RBAC** — `AdminAuthService.resolveAccess` só considera founder + `admins/{uid}`; **não** `users.isAdmin`. `AdminGate` usa legado **OU** RBAC (`canAccessAdminPanel`). | **Alto** | Unificar: `resolveAccess` incluir `isAdmin` e papéis RBAC, ou home usar mesmo gate que `AdminPage`. | Quem é admin no Firestore acessa admin de forma consistente. | **P0** |
| R2 | **Botão oculto na home** usa só `resolveAccess` (sem RBAC / `isAdmin` completo). | **Alto** | Chamar `RbacService.canAccessAdminPanel` ou abrir sempre `AdminPage` (já tem `AdminGate`). | Mesmo critério em todos os pontos de entrada. | **P0** |
| R3 | **Dupla matriz de permissões** — `RolePermissionMatrix` (código) + `platform_rbac_roles` (Firestore). Seed só se coleção vazia. | Médio | Migração incremental de permissões novas (ex. `platform.settings`); job de sync versão app ↔ Firestore. | Deploys novos não deixam papéis desatualizados. | P1 |
| R4 | **`platform_rbac_*` legível por qualquer `isSignedIn()`** — catálogo de permissões exposto. | Baixo | Aceitável para app cliente; sensível se permissões forem estratégicas. | Restringir se necessário. | P3 |
| R5 | **Papéis `finance`, `affiliate`, `partner`** no enum sem seed nos 5 perfis principais. | Baixo | Documentar ou incluir no seed se forem usados. | Menos surpresa ao atribuir papéis. | P3 |
| R6 | **Legacy admin recebe papel `admin` automaticamente** no `PermissionChecker` sem `rbacRoles` no documento. | Médio | Gravar `rbacRoles` explicitamente ao promover admin. | Revogação RBAC previsível. | P2 |

---

## 6. Auditoria

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| U1 | **Qualquer usuário pode criar `platform_audit_logs`** (rules). | Médio | Ver S5 — server-side only. | Trilha de auditoria íntegra. | P1 |
| U2 | **Tipos de evento definidos** mas poucos usados no legado (login, pagamento, etc.). | Baixo | Instrumentar fluxos críticos gradualmente. | Observabilidade comercial futura. | P3 |
| U3 | **Painel mestre abre shell** — log `adminAction` ok; volume alto se muitos refreshes. | Baixo | Debounce ou agregar “session” no metadata. | Custo Firestore de logs. | P3 |
| U4 | **Contagem dupla de admins** no dashboard (`admins` + `users.isAdmin`) — métrica inflada. | Baixo | Contagem distinta (set union) ou só `admins`. | KPI admin correto. | P3 |

---

## 7. Repositórios e serviços

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| V1 | **`QuestaoService.getTodasQuestoes()`** — stream da coleção **inteira** `questoes`. | **Alto** | Paginação, filtros, ou leitura só admin com limite. | Performance e custo em escala. | **P0** |
| V2 | **`OsceRoomService.streamAllOpenRooms()`** — snapshots em **toda** `osce_rooms`; filtro em memória. | **Alto** | Query Firestore por `status`; índice. | Lobby OSCE escalável. | **P0** |
| V3 | **`_allocateRoomNumber` fallback** — `get()` em todas as salas se meta falhar. | **Alto** | Retry transação; nunca full scan no cliente. | Evita timeout/custo explosivo. | **P0** |
| V4 | **Serviços duplicáveis** — `FirebaseService`, `QuestaoService`, `PracticalPhaseRepository`, `OsceCaseAdminService` todos tocam conteúdo/admin. | Médio | Facades por domínio (Conteúdo, OSCE, Questões). | Manutenção mais barata. | P2 |
| V5 | **`PaymentRepository`** só usado pela infraestrutura; sem UI de pagamento. | Baixo | Manter até gateway; documentado. | Nenhum até checkout. | P3 |
| V6 | **`LiveEventNotificationService`** — stub vazio, sem FCM. | Baixo | Implementar ou marcar `@Deprecated`. | Expectativa de push não frustrada. | P3 |
| V7 | **`MasterAdminDashboardService`** — N+1 contagens no open do dashboard. | Médio | Cloud Function diária + doc `platform_stats/summary`. | Abertura rápida do painel. | P2 |

---

## 8. Navegação

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| N1 | **Admin: apenas `AdminPage` usa `AdminGate`**; subtelas admin não têm `RbacGate` por feature. | Médio | Gates por rota sensível (ex. mensagem global, live events). | Suporte/vendedor com least privilege. | P2 |
| N2 | **Painel Mestre** — `AdminGate` + `RbacGate` aninhados; entrada dupla se já passou admin conteúdo. | Baixo | Aceitável; opcional gate único no shell. | Menos latência dupla. | P3 |
| N3 | **Sem rota nomeada / deep link** — tudo `MaterialPageRoute`. | Baixo | `go_router` quando app crescer. | Testes e links externos. | P3 |

---

## 9. Dependências

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| D1 | **`path` no pubspec** — sem `import 'package:path/'` no código. | Baixo | Remover dependência transitiva explícita se não necessária. | Menor superfície de deps. | P3 |
| D2 | **`assets/sounds/beep.mp3`** declarado no pubspec — **arquivo ausente** no repo. | Médio | Adicionar asset ou remover entrada; fallback só haptic. | Evita erro em build/release. | P1 |
| D3 | **`flutter_html` beta** — possível dívida de compatibilidade. | Baixo | Acompanhar stable ou substituir onde Quill cobre. | Menos breaking changes. | P3 |
| D4 | **`universal_html`** só em `firebase_service.dart` — acoplamento web. | Baixo | `kIsWeb` + implementação condicional já comum no projeto. | OK se multi-plataforma for meta. | P3 |

---

## 10. Código morto / duplicado

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| C1 | `ProgressoService` | Médio | Remover ou integrar | Ver F3 | P2 |
| C2 | `PracticalPhaseLandingPage` sem navegação | Médio | Ligar na home ou remover | Ver A6 | P2 |
| C3 | Admin Fase Prática modelos sem menu | Médio | Entrada em `AdminPage` | Ver A5 | P2 |
| C4 | `LiveEventNotificationService` stub | Baixo | Implementar FCM ou remover exports | Ver V6 | P3 |
| C5 | `lib/core/core.dart` não usado | Baixo | Adotar ou apagar | Ver A2 | P3 |

---

## 11. Memória e widgets

| # | Problema | Risco | Sugestão de correção | Impacto da correção | Prioridade |
|---|----------|-------|----------------------|---------------------|------------|
| M1 | **`StudyTimerOverlay`** — `studyTimeStream` / `pauseTimeStream` `.listen()` sem cancel no `dispose`. | Médio | Guardar `StreamSubscription` e `cancel()`. | Evita leak ao sair da árvore de widgets. | P1 |
| M2 | **`tela_flashcards` / `questoes_por_tema_page`** — `alertStream.listen` sem cancel. | Médio | Idem M1. | Mesmo padrão. | P1 |
| M3 | **`StudyTimerService` singleton** — múltiplos listeners acumulam se telas abrem/fecham. | Médio | Broadcast stream com contagem de listeners ou dispose central. | Estabilidade longa sessão estudo. | P1 |
| M4 | **Quill / `FlashcardReadonlyQuill`** — controllers pesados; várias instâncias em listas OSCE/prática. | Médio | `studyMode`, lazy build, `AutomaticKeepAliveClientMixin` seletivo. | FPS em telas longas. | P2 |
| M5 | **Home com múltiplos `StreamBuilder`** aninhados (usuário, eventos, etc.). | Baixo | `rx` combinado ou um stream de ViewModel. | Menos rebuilds. | P3 |

---

## 12. Consultas Firestore ineficientes

| # | Problema | Risco | Sugestão | Impacto | Prioridade |
|---|----------|-------|----------|---------|------------|
| Q1 | Lobby OSCE — coleção inteira | Alto | Query + índice | Ver V2 | P0 |
| Q2 | Questões — coleção inteira em admin | Alto | Limite / paginação | Ver V1 | P0 |
| Q3 | Dashboard — ~12 `count()` + 200 subs para receita | Médio | Agregação server | Ver V7 | P2 |
| Q4 | Master admin users — `limit(100)` sem ordem | Baixo | `orderBy` + índice | Lista previsível | P3 |
| Q5 | Flashcards por matéria — múltiplos `.get()` em `FirebaseService` | Médio | Cache local ou query composta | Menos leituras repetidas | P2 |

---

## Matriz de priorização (top 10)

| Prioridade | IDs | Tema |
|------------|-----|------|
| **P0** | F1, F4, S1–S4, I4, R1–R2, V1–V3 | Segurança Firestore + progresso + admin inconsistente + queries OSCE/questões |
| **P1** | S5–S6, S9, R3, U1, D2, M1–M3 | Auditoria, assinaturas, leaks, asset faltando |
| **P2** | A1, A5–A6, F5, I1–I2, R6, V4, V7, N1, M4, Q5 | Arquitetura, UX, performance média |
| **P3** | Demais | Higiene, docs, deps |

---

## Serviços candidatos a unificação (recomendação)

| Domínio | Situação atual | Unificação sugerida |
|---------|----------------|---------------------|
| **Admin / auth** | `AdminAuthService`, `RbacService`, rules `isAppAdmin` | `AdminAccessFacade` único usado por Home, AdminGate, rules sync |
| **Progresso aluno** | `users/progresso`, `progresso_questoes`, `usuarios` morto | `UserProgressRepository` com subpaths documentados |
| **Conteúdo** | `FirebaseService` + repos admin OSCE/prática | `ContentAdminService` delegando a repos |
| **Comercial** | `PlatformRegistry` (já central) | Expandir quando pagamentos existire em vez de novos singletons |
| **OSCE** | `OsceRoomService`, `OsceEvaluationService`, `OscePerformanceService` | Manter separados por bounded context; corrigir queries |

---

## Conclusão

O projeto está **funcional para o núcleo de estudo** (flashcards, questões, OSCE), com **fundação comercial e RBAC bem encaminhada**, mas com **dívida técnica relevante em segurança Firestore**, **modelo de dados de usuário/progresso** e **pontos de entrada admin divergentes**. Recomenda-se tratar itens **P0** antes de escalar usuários ou abrir pagamentos públicos.

---

*Relatório gerado por análise estática do código-fonte e rules; validar em ambiente Firebase real (índices, métricas, custos).*
