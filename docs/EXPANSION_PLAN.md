# Plano de expansão — Trilha Med / Revalida Cards

**Data:** 2026-05-19  
**Papel:** Arquitetura preparatória (sem alterar comportamento atual do app)

---

## 1. Análise da estrutura atual

### 1.1 Visão geral

| Camada | Situação atual |
|--------|----------------|
| **UI** | `lib/screens/` + `lib/widgets/` — majoritariamente `StatefulWidget` + `setState` |
| **Estado global** | `StudyTimerService` (`ChangeNotifier`); resto via Firestore `StreamBuilder` |
| **Negócio** | `lib/services/` — acesso direto ao Firestore (exceto Fase Prática) |
| **Persistência** | Firebase Auth, Firestore, Storage, SharedPreferences, Secure Storage |
| **Repositório** | Apenas `PracticalPhaseRepository` (padrão a replicar) |
| **Regras** | `firestore.rules` + `storage.rules` |

**Não há:** Provider, Riverpod, Bloc, GoRouter, FCM integrado.

### 1.2 Modelos existentes (`lib/models/`)

| Modelo | Domínio |
|--------|---------|
| `pergunta.dart` | Flashcards legado/local |
| `questao_model.dart` | Banco de questões MCQ |
| `simulado_models.dart` | Simulados |
| `osce_models.dart`, `osce_evaluation_models.dart`, `osce_script_fields.dart` | OSCE multiplayer |
| `live_event_models.dart` | Eventos ao vivo |
| `practical_phase_model.dart`, `practical_phase_module.dart` | Fase prática |
| `performance_models.dart` | Desempenho OSCE |
| `estatistica_materia.dart` | Estatísticas de estudo |

### 1.3 Serviços existentes (`lib/services/`)

| Serviço | Responsabilidade |
|---------|------------------|
| `firebase_service.dart` | Flashcards |
| `questao_service.dart` | Questões + progresso + reports |
| `progresso_service.dart` | Progresso flashcards em **`usuarios`** |
| `cronograma_service.dart` | Cronograma em **`users`** |
| `simulado_service.dart` | Simulados |
| `study_timer_service.dart` | Timer Pomodoro + aparência |
| `global_message_service.dart` | Mensagens globais |
| `live_event_service.dart` | Eventos live |
| `practical_phase_*` | Fase prática |
| `osce/*` | Salas, casos, avaliações, performance |
| `auth/*` | Perfil, admin, credenciais |

### 1.4 Coleções Firestore em uso

**Raiz:** `admins`, `users`, `usuarios`, `flashcards`, `questoes`, `notificacoes_admin`, `global_messages`, `osce_*`, `live_events`, `practical_phase_*`

**Subcoleções `users/{uid}`:** `progresso`, `progresso_questoes`, `questao_reports`, `simulados_historico`, `cronograma_*`

**Dívida técnica conhecida:** progresso em `users` vs `usuarios` — **não será alterada nesta fase** para não quebrar dados em produção.

### 1.5 Admin e permissões hoje

- **Servidor:** `isFounder`, `isListedAdmin`, `isAppAdmin` (`users.isAdmin`)
- **Cliente:** `AdminAuthService`, `AdminGate`
- **Sem RBAC granular** (vendedor, afiliado, financeiro, etc.)

---

## 2. Objetivos da expansão

Preparar **modelos, contratos (repositórios), infraestrutura Firestore e regras** para:

| Módulo | Prioridade futura |
|--------|-------------------|
| Usuários estendidos | Perfil comercial, papéis, metadados |
| Assinaturas | Planos + status + renovação |
| Pagamentos | Transações, reembolsos, webhooks (backend) |
| Vendedores | Comissões, metas |
| Afiliados | Links, conversões |
| Cupons | Desconto, validade, uso |
| Parcerias | B2B, white-label |
| Propagandas | Slots, impressões |
| Auditoria | Trilha imutável de ações |
| Notificações in-app | Caixa do usuário (≠ `notificacoes_admin`) |
| Dashboard admin | Agregações (leitura) |
| Permissões | RBAC sobre `AppRole` + `Permission` |

---

## 3. Princípios (não quebrar o app)

1. **Código novo em pastas isoladas** — `lib/core/`, `lib/domain/platform/`, `lib/infrastructure/`.
2. **Nenhuma tela existente importa** os novos módulos nesta entrega (comportamento idêntico).
3. **Repositórios Firestore implementados** mas consumidos apenas via `PlatformRegistry` (opt-in futuro).
4. **Regras Firestore** para novas coleções — admin gerencia catálogo; usuário lê apenas o próprio.
5. **Documentação** em `docs/ARCHITECTURE.md`.

---

## 4. Arquivos que serão criados (novos)

| Caminho | Motivo |
|---------|--------|
| `lib/core/constants/firestore_paths.dart` | Nomes únicos de coleções (evita strings espalhadas) |
| `lib/core/permissions/*` | RBAC preparatório |
| `lib/core/audit/*` | Modelo de log de auditoria |
| `lib/domain/platform/enums/*` | Status de assinatura, pagamento, etc. |
| `lib/domain/platform/models/*` | Entidades de crescimento |
| `lib/domain/platform/repositories/*` | Contratos (interfaces) |
| `lib/infrastructure/firestore/platform/*` | Implementações Firestore |
| `lib/application/platform/platform_registry.dart` | Ponto único de injeção futura |
| `docs/ARCHITECTURE.md` | Documentação completa |
| `firestore.rules` (trecho) | Regras das novas coleções |

## 5. Arquivos que NÃO serão alterados nesta fase

| Área | Motivo |
|------|--------|
| `lib/main.dart` | Evitar mudança de bootstrap |
| Telas em `lib/screens/` | Sem mudança de UX |
| Serviços atuais (`questao_service`, OSCE, etc.) | Sem refatoração invasiva |
| `users` / `usuarios` progresso | Migração é projeto separado |

## 6. Arquivos alterados minimamente

| Arquivo | Alteração |
|---------|-----------|
| `firestore.rules` | Novos `match` para coleções `platform_*` e subcoleções de usuário |
| `firestore.indexes.json` | Índices opcionais para consultas admin (se necessário) |

---

## 7. Roadmap sugerido (após esta entrega)

| Fase | Entrega |
|------|---------|
| **A (feito agora)** | Modelos + repositórios + regras + docs |
| **B** | `UserProfileService` grava `roles[]`; tela admin de planos |
| **C** | Checkout (Stripe/MP) via Cloud Functions + `payments` |
| **D** | Dashboard admin com `AdminDashboardService` |
| **E** | FCM + `user_notifications` |
| **F** | Unificar `users` / `usuarios` progresso |

---

## 8. Riscos e mitigação

| Risco | Mitigação |
|-------|-----------|
| Regras bloqueiam escrita legada | Novas coleções isoladas; regras antigas intactas |
| Duplicação de “notificação” | `notificacoes_admin` (suporte) vs `users/.../notifications` (in-app) |
| Pacote grande demais | Registry lazy; nada importado pelo `main` |

---

## 9. Critérios de aceite desta entrega

- [x] Relatório de análise (este documento)
- [x] Modelos e enums para todos os domínios listados
- [x] Interfaces de repositório + implementação Firestore
- [x] `PlatformRegistry` sem uso obrigatório no app
- [x] Regras Firestore para novas coleções
- [x] `docs/ARCHITECTURE.md` detalhado
- [x] App compila e comportamento das telas atuais inalterado
