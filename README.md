# Revalida Cards (TrilhaMed)

Aplicativo Flutter para estudo (flashcards, questões, simulados, OSCE, fase prática, eventos ao vivo e módulo comercial).

**Firebase:** `revalida-cards`

## Status do projeto

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

[![codecov](https://codecov.io/gh/OWNER/REPO/graph/badge.svg)](https://codecov.io/gh/OWNER/REPO)

> Substitua `OWNER/REPO` no badge de cobertura pelo caminho do seu repositório GitHub (ex.: `marci/revalida-cards`) após conectar o projeto no [Codecov](https://codecov.io).

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [docs/CI_CD.md](docs/CI_CD.md) | Pipeline GitHub Actions, secrets, cobertura |
| [docs/PRODUCTION_READINESS_REPORT.md](docs/PRODUCTION_READINESS_REPORT.md) | Auditoria de prontidão para produção |
| [docs/TEST_COVERAGE_REPORT.md](docs/TEST_COVERAGE_REPORT.md) | Cobertura de testes por domínio |
| [docs/MERCADO_PAGO_IMPLEMENTATION.md](docs/MERCADO_PAGO_IMPLEMENTATION.md) | Checkout e webhook |

## Desenvolvimento local

```bash
flutter pub get
flutter analyze lib
flutter test --coverage
```

```bash
cd functions && npm ci && npm test
```

## CI

A cada **push** e **pull request** nas branches `main`, `master` e `develop`:

1. `flutter analyze` + `flutter test --coverage`  
2. `npm test` em `functions/`  
3. Validação de `firestore.rules` e `firestore.indexes.json`  

Sem deploy automático. Detalhes em [docs/CI_CD.md](docs/CI_CD.md).

## Getting Started (Flutter)

- [Documentação Flutter](https://docs.flutter.dev/)
- [Lab: primeiro app](https://docs.flutter.dev/get-started/codelab)
