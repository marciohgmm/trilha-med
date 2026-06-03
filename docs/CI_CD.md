# CI/CD — Trilha Med

Pipeline de **validação automática** em push e pull request. **Não há deploy automático** para Firebase, lojas ou hosting.

## Visão geral

| Job | O que executa | Falha quando |
|-----|----------------|--------------|
| **Flutter** | `flutter analyze lib`, `flutter test --coverage` | Analyze com erros/warnings fatais; qualquer teste falha |
| **Functions** | `npm ci`, `npm test` (TypeScript build + testes Node) | Build ou teste falha |
| **Firestore** | Testes de rules/indexes + dry-run opcional | Testes falham; dry-run falha se `FIREBASE_TOKEN` configurado |

Arquivo do workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

## Gatilhos

- `push` nas branches: `main`, `master`, `develop`
- `pull_request` para as mesmas branches

`concurrency` cancela execuções anteriores da mesma branch para economizar minutos.

## Executar localmente

### Flutter

```bash
flutter pub get
flutter analyze lib --no-fatal-infos
flutter test --coverage
python3 scripts/coverage_summary.py
```

Relatório: `coverage/coverage-summary.md` e `coverage/lcov.info`.

### Cloud Functions

```bash
cd functions
npm ci
npm test
```

Inclui:

- `test/push.test.mjs` — preferências de push  
- `test/firestore-config.test.mjs` — estrutura de índices, duplicatas e checks estruturais de `firestore.rules`

### Firestore (dry-run completo)

Requer login CI do Firebase:

```bash
npm install -g firebase-tools
firebase login:ci
# Adicionar token como secret FIREBASE_TOKEN no GitHub

firebase deploy \
  --only firestore:rules,firestore:indexes \
  --dry-run \
  --project revalida-cards \
  --non-interactive
```

Sem `FIREBASE_TOKEN`, o job **Firestore** ainda valida a compilação das rules via **Firestore Emulator** (`firebase emulators:exec`).

## Cobertura

### Artefatos

Cada run do job Flutter publica:

- `coverage/lcov.info` — formato lcov  
- `coverage/coverage-summary.md` — percentual resumido  

Baixe em **Actions → workflow run → Artifacts → flutter-coverage**.

### Codecov (opcional)

O workflow envia `coverage/lcov.info` para [Codecov](https://codecov.io) se o repositório estiver conectado.

1. Acesse [codecov.io](https://codecov.io) e importe o repositório GitHub.  
2. (Repositórios privados) Adicione o secret `CODECOV_TOKEN` nas configurações do repo.  
3. Atualize o badge no `README.md` substituindo `OWNER/REPO` pelo caminho real (`usuario/repositorio`).

### Badge no README

```markdown
[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/OWNER/REPO/graph/badge.svg)](https://codecov.io/gh/OWNER/REPO)
```

O badge de CI usa caminho relativo e funciona em qualquer fork sem edição.

## Secrets recomendados

| Secret | Obrigatório | Uso |
|--------|-------------|-----|
| `FIREBASE_TOKEN` | Recomendado | `firebase deploy --dry-run` de rules e indexes |
| `CODECOV_TOKEN` | Opcional | Upload para Codecov em repos privados |

Gerar token Firebase:

```bash
firebase login:ci
```

## O que o pipeline não faz

- Deploy de Hosting, Functions ou Firestore  
- Publicação em Play Store / App Store  
- Assinatura de builds release  
- Scan de dependências (Dependabot pode ser adicionado depois)  

## Analyzer — infos conhecidos

O projeto pode reportar ~16 issues **info** (`use_build_context_synchronously`, `deprecated_member_use` em formulários do Painel Mestre). O CI usa `--no-fatal-infos` para não bloquear por infos; **erros e warnings** continuam falhando o analyze quando fatais.

Para endurecer:

```bash
flutter analyze lib
# ou remover --no-fatal-infos no workflow após corrigir infos
```

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| Job Flutter timeout | Primeiro `pub get` lento | Re-run; cache do `flutter-action` |
| `firestore-config` falha | Erro de sintaxe em `firestore.rules` | Corrigir rules; rodar `cd functions && npm test` |
| Dry-run Firebase ignorado | Sem `FIREBASE_TOKEN` | Configurar secret ou confiar nos testes rules-unit-testing |
| Codecov 404 no badge | Repo não conectado | Importar no codecov.io e ajustar URL do badge |

## Evolução sugerida

1. Aumentar cobertura mínima com `very_good_coverage` ou threshold no script.  
2. Adicionar job `functions` ESLint (`npm run lint`).  
3. Testes de integração webhook MP com emulador ou mocks.  
4. Matrix `flutter` em versões estável/beta (opcional).  

---

*Última atualização: 2026-05-19*
