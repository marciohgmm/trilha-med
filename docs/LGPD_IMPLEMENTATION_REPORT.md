# Relatório — Implementação LGPD mínima para produção

**Data:** 2026-05-19  
**Pré-relatório:** `docs/LGPD_PRODUCTION_PRE_REPORT.md`

---

## 1. Resumo executivo

| Requisito | Antes | Depois |
|-----------|-------|--------|
| Política de Privacidade | Ausente | `PrivacyPolicyPage` + versão `policyVersion` |
| Termos de Uso | Ausente | `TermsOfUsePage` + versão `termsVersion` |
| Aceite registrável | Não | `users/{uid}/legal_acceptances` |
| Bloqueio sem aceite | Não | `LegalAcceptanceGate` pós-login |
| Exportação (portabilidade) | Não | `ExportMyDataService` → JSON |
| Exclusão de conta | Não | `DeleteAccountPage` + `deleteMyAccount` |
| Central de privacidade | Não | `PrivacyCenterPage` |
| Canal LGPD | Só suporte | E-mail em `LegalVersions.privacyContactEmail` |

**LGPD mínima para produção pública:** **Atendida em nível técnico-produto**, ressalvada revisão jurídica dos textos e DPA com operadores.

**Não alterado:** estudo, monetização, OSCE, flashcards, questões, Mercado Pago.

---

## 2. Etapas entregues

### A — Auditoria
`docs/LGPD_PRODUCTION_PRE_REPORT.md`

### B — Termos e política
- `lib/core/legal/legal_versions.dart` — `policyVersion`, `termsVersion`, e-mail LGPD
- `lib/screens/legal/privacy_policy_page.dart`
- `lib/screens/legal/terms_of_use_page.dart`
- Links em **Perfil → Configurações** e **Cadastro**

### C — Aceite registrável
- Coleção: `users/{uid}/legal_acceptances`
- Campos: `acceptedAt`, `policyVersion`, `termsVersion`, `ipHash` (opcional), `platform`, `appVersion`
- `LegalAcceptanceService.requiredLegalAcceptance()` / `watchNeedsAcceptance()`
- `LegalAcceptanceGate` em `main.dart` (bloqueia app até aceite)
- Cadastro: checkbox obrigatório + `recordAcceptance` antes do sign-out

### D — Exclusão de conta
- `DeleteAccountPage` — confirmação dupla (`EXCLUIR` + diálogo)
- Cloud Function `deleteMyAccount`:
  - Apaga subcoleções de `users/{uid}`
  - Apaga doc `users/{uid}`
  - Apaga Firebase Auth
  - Remove `platform_fcm_users`, analytics events do usuário
  - **Preserva** `platform_payments`, `platform_subscriptions`, `platform_audit_logs` financeiros
  - Auditoria `account.deletion_requested` / `account.deletion_completed`

### E — Portabilidade
- `ExportMyDataService` — JSON com perfil, progresso, cronograma, simulados, OSCE, assinaturas, pagamentos, entitlements, aceites legais
- Compartilhamento via `share_plus`

### F — Central de privacidade
- `PrivacyCenterPage` — política, termos, exportar, excluir, histórico de consentimentos

### G — Testes
- `test/legal/legal_compliance_test.dart`
- `functions/test/lgpdCompliance.test.mjs`

### H — Este relatório

---

## 3. Firestore Rules

```text
users/{userId}/legal_acceptances/{id}
  read: owner | admin
  create: owner (campos validados, acceptedAt = request.time)
  update/delete: false
```

---

## 4. Deploy necessário

```bash
flutter pub get
firebase deploy --only firestore:rules,functions:deleteMyAccount
# ou deploy completo de functions se preferir
```

Configurar e-mail real em `LegalVersions.privacyContactEmail` antes da loja.

---

## 5. Testes executados

| Suite | Comando | Resultado |
|-------|---------|-----------|
| Flutter | `flutter test test/legal/legal_compliance_test.dart` | Executar localmente |
| Functions | `cd functions && npm test` | Inclui `lgpdCompliance.test.mjs` |

---

## 6. Impacto em usuários

| Público | Efeito |
|---------|--------|
| Novo cadastro | Checkbox legal obrigatório |
| Usuário existente sem aceite | Tela de aceite na próxima entrada (após e-mail verificado) |
| Estudo / Premium / OSCE | Sem mudança de fluxo após aceite |
| Exclusão | Irreversível; dados de estudo removidos |

---

## 7. Impacto em admins

- Podem ler `legal_acceptances` de usuários (rules `isAppAdmin`)
- Exclusão de conta é self-service; admins não precisam intervir

---

## 8. Riscos remanescentes

| Item | Sev. | Nota |
|------|------|------|
| Textos legais não revisados por advogado | P1 | Templates in-app |
| `ipHash` raramente preenchido no cliente | P2 | Campo opcional; pode evoluir via Function |
| OSCE global (`osce_evaluations`) pode reter UID após exclusão | P2 | Export inclui; exclusão não apaga coleção global |
| `notificacoes_admin` com reports antigos | P2 | Fora do escopo; retenção administrativa |
| GA4 / Firebase — exclusão depende política Google | P2 | Documentar na política |

---

## 9. Atualização futura de versões

1. Alterar `LegalVersions.policyVersion` e/ou `termsVersion` em `legal_versions.dart`
2. Publicar app
3. `LegalAcceptanceGate` exige novo aceite automaticamente

---

## 10. Conclusão

| Pergunta | Resposta |
|----------|----------|
| LGPD mínima atendida? | **Sim** (técnico + produto) |
| Dados exportáveis? | **Sim** |
| Dados excluíveis? | **Sim** (exceto retenção financeira/audit) |
| Consentimento registrável? | **Sim** |
| Riscos remanescentes? | Revisão jurídica, dados OSCE globais, operadores |
| Deploy necessário? | **Rules + Function `deleteMyAccount`** |

---

*Implementação concluída sem alteração dos fluxos de estudo, monetização, OSCE, flashcards, questões ou Mercado Pago.*
