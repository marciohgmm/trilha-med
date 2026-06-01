# Feature Flags — Relatório de implementação (Etapas 2–8)

**Data:** 2026-05-19  
**Pré-relatório:** [FEATURE_FLAGS_PRE_REPORT.md](./FEATURE_FLAGS_PRE_REPORT.md)

---

## ANTES × DEPOIS

| Área | Antes | Depois |
|------|-------|--------|
| Controle remoto de módulos | Não existia | `platform_feature_flags` + Painel Mestre |
| Home / OSCE / Simulados | Sempre visíveis | `FeatureGate` / `FeatureGateSection` |
| Manutenção | Só nova versão do app | `MaintenancePage` + mensagem configurável |
| Auditoria | — | `feature_flag.updated` em `platform_audit_logs` |
| RBAC | — | `feature_flags.manage` |

**Preservado:** monetização Mercado Pago, conteúdo pedagógico, fluxo OSCE interno, Fase Prática (landing/admin).

---

## Etapa 2 — Coleção `platform_feature_flags`

Documentos padrão (seed idempotente):

`flashcards`, `questoes`, `simulados`, `cronograma`, `fase_pratica`, `osce`, `live_events`, `ferramentas_medicas`, `premium`, `marketplace`

Campos: `enabled`, `maintenanceMode`, `maintenanceMessage`, `updatedAt`, `updatedBy`

---

## Etapa 3 — Serviços

| Arquivo | Função |
|---------|--------|
| `lib/models/feature_flag_model.dart` | Modelo |
| `lib/services/feature_flags/feature_flag_service.dart` | `isEnabled`, `isInMaintenance`, `getModule`, `watchModule` / `watchAll`, cache TTL 5 min |
| `lib/core/feature_flags/feature_modules.dart` | IDs e labels |
| `lib/data/feature_flag_default_seed.dart` | Defaults |

---

## Etapa 4 — Painel Mestre

`FeatureFlagsAdminPage` — menu **Feature flags**  
Permissão: `feature_flags.manage` (fallback `platform.settings` / founder)  
Salvamento em tempo real + auditoria estruturada (`action`, `blocked`, `reason`, before/after).

---

## Etapa 5 — App

| Widget | Uso |
|--------|-----|
| `FeatureGate` | Botões com `childBuilder(onPressed)` |
| `FeatureGateSection` | Ocultar seções (Live Events) |
| `FeatureGatePage` | Telas inteiras (OSCE lobby) |
| `MaintenancePage` | Título, mensagem, Voltar |

---

## Etapa 6 — Home integrada

- Flashcards, Questões, Fase Prática, Ferramentas Médicas  
- Live Events (`FeatureGateSection`)  
- Cronograma (dashboard flashcards)  
- Simulados (botão em Questões)  
- OSCE (`FeatureGatePage` no lobby)

**Não integrado nesta fase:** `premium` / `marketplace` (flags reservadas; checkout inalterado).

---

## Etapa 7 — Testes

| Arquivo | Cobertura |
|---------|-----------|
| `test/feature_flags/feature_flags_test.dart` | Model, `resolveOnPressed`, manutenção |
| `test/feature_flags/feature_flags_rules_test.dart` | Rules, RBAC, audit enum |
| `functions/test/firestore-config.test.mjs` | Rules snapshot |

Comando: `flutter test test/feature_flags/`

---

## Leituras Firestore / custo

| Cenário | Leituras |
|---------|----------|
| App aberto | 1 listener na coleção (~10 docs) — compartilhado |
| Cache 5 min | Reduz `get()` repetidos |
| Admin | Mesmo stream + writes pontuais |

Impacto: **baixo** (~10 documentos pequenos por sessão).

---

## Impacto UX

- Módulo **desligado:** botão some na Home (fail-safe: default ativo se offline).  
- **Manutenção:** usuário vê mensagem clara e volta.  
- Admins: controle sem deploy.

---

## Deploy necessário

1. `firebase deploy --only firestore:rules`  
2. Abrir Painel Mestre → Feature flags (cria seed automático)  
3. Atribuir `feature_flags.manage` ao papel master no Firestore **ou** usar founder  
4. Build/release do app Flutter

---

## Riscos remanescentes

- RBAC em Firestore existente pode não incluir `feature_flags.manage` até re-seed manual da permissão no papel  
- Live Events em manutenção ainda exibe seção (só oculta se `enabled=false`)  
- Deep links diretos a telas sem `FeatureGatePage` podem contornar gate  

---

## Arquivos principais

```
lib/services/feature_flags/feature_flag_service.dart
lib/widgets/feature_flags/feature_gate.dart
lib/screens/master_admin/modules/feature_flags_admin_page.dart
lib/screens/maintenance/maintenance_page.dart
firestore.rules — platform_feature_flags
```
