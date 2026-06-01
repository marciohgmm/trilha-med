# P0-3 — Proteção de conteúdo (pré-implementação)

**Data:** 2026-05-19  
**Escopo:** `flashcards`, `questoes`, telas do aluno e admin  
**Objetivo:** documentar exposição atual antes da correção anti-scraping.

---

## 1. Regras Firestore (antes)

```javascript
match /flashcards/{docId} {
  allow read: if isSignedIn();  // get + list sem restrição
  allow write: if isAdmin();
}
match /questoes/{docId} {
  allow read: if isSignedIn();
  allow write: if isAdmin();
}
```

**Risco:** qualquer usuário autenticado pode executar `collection('flashcards').get()` ou `.snapshots()` e baixar **100%** do banco via SDK/script.

---

## 2. Queries `flashcards`

| Arquivo | Query | Tipo | Público | Risco |
|---------|-------|------|---------|-------|
| `cronograma_service.dart` | ~~`.get()` completo~~ | P0-6 corrigido | Aluno | — |
| `subtemas_page.dart` | `.where('materia').snapshots()` | Stream | Aluno | Alto por matéria |
| `tela_flashcards.dart` | `.where(materia+subtema).snapshots()` | Stream | Aluno | Legítimo (estudo) |
| `busca_flashcard_delegate.dart` | `searchTerms` + `limit(30)` | Stream | Aluno | Baixo |
| `tela_flashcards_por_ids.dart` | `whereIn(ids)` | Get | Aluno | Baixo |
| `firebase_service.dart` | CRUD, export `.get()` | Admin | Admin | OK |
| `flashcard_materia_stats_service.dart` | rebuild paginado | Seed | Sistema | OK |
| `flashcard_subtema_catalog_service.dart` | rebuild paginado | Seed | Sistema | OK |
| `admin_materias_page.dart` | `.snapshots()` completo | Stream | Admin | OK |
| `admin_cards_page.dart` | filtros admin | Admin | Admin | OK |
| `criar_flashcard_page.dart` | ~~`.get()` completo~~ | Admin | Admin | Corrigido |
| `questao_service.dart` | `limit(200)` fallback | Get | Sistema | Médio |

---

## 3. Queries `questoes`

| Arquivo | Query | Tipo | Público | Risco |
|---------|-------|------|---------|-------|
| `questoes_por_tema_page.dart` | ~~`.snapshots()` completo~~ | Stream | Aluno | **Crítico** |
| `subtemas_page.dart` | ~~`.where('materia').snapshots()`~~ | Stream | Aluno | Alto |
| `questoes_page.dart` | `.where('materia').snapshots()` | Stream | Aluno | Legítimo |
| `questao_service.dart` | ~~`.get()` matérias~~, `getTodasQuestoes()` | Get/Stream | Admin | Corrigido |
| `simulado_service.dart` | ~~paginação `orderBy(__name__)`~~ | Get | Aluno | **Crítico** |
| `live_event_service.dart` | ~~`.get()` matérias~~, picker | Admin/Host | Médio | Corrigido |
| `admin_questoes_*` | snapshots/listas | Admin | Admin | OK |
| `estatisticas_questoes_page.dart` | só `progresso_questoes` | Stream | Aluno | OK |

---

## 4. Telas dependentes

| Tela | Coleção | Uso |
|------|---------|-----|
| Home | `flashcards_materia_stats` | Stats (P0-1) |
| Subtemas | catálogo / conteúdo | Navegação |
| TelaFlashcards | `flashcards` | Estudo |
| Questões por matéria | stats | Lista matérias |
| QuestoesPage | `questoes` | Estudo |
| Simulado | `questoes` por matéria | Montagem |
| Cronograma | catálogo subtemas | Sync (P0-6) |
| Busca flashcards | `searchTerms` | Descoberta |
| Live Events / OSCE | `questoes` filtradas | Jogo |
| Admin * | full access | Gestão |

---

## 5. Vetores de scraping identificados

1. **`questoes.snapshots()`** na home de questões — dump contínuo.
2. **`flashcards/questoes.get()`** sem filtro — script de 1 linha.
3. **Simulado “todas matérias”** — paginação por `documentId` lendo coleção inteira.
4. **Subtemas** — stream de todos os cards de uma matéria (metadados + conteúdo).
5. **Regras** — não distinguem `get` vs `list` nem impõem filtros/limites.

---

## 6. Estratégia proposta (Etapa B — beta, menor risco)

| Camada | Ação |
|--------|------|
| **Catálogos agregados** | `questoes_materia_stats`, `questoes_subtema_catalog` (espelho P0-1/P0-6) |
| **Navegação** | Listar matérias/subtemas só via catálogo (~dezenas/centenas de docs) |
| **Conteúdo sob demanda** | Carregar `flashcards`/`questoes` apenas com filtro matéria (+ subtema na UI) |
| **Paginação / limites** | `ContentQueryLimits` alinhado às rules (busca 30, estudo 500, picker 200) |
| **Rules** | `list` bloqueado sem filtro escopo; admin (`isAppAdmin`) bypass |
| **UX aluno** | Inalterada — mesmas telas, mesmos fluxos |

---

## 7. Fora de escopo imediato (futuro / monetização)

- Cloud Functions proxy para simulado (rate limit por UID).
- Entitlements `platform_entitlements` restringindo matérias premium.
- App Check + detecção de abuso por volume de reads.

Este documento serve como linha de base para `P0-3_CONTENT_PROTECTION_REPORT.md`.
