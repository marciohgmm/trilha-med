# P0-1 — Agregação da Home (flashcards por matéria)

**Data:** 2026-05-19  
**Escopo:** `HomeDashboardPage` — seção **Matérias** (estatísticas + progresso)  
**Objetivo:** eliminar `snapshots()` / `get()` na coleção raiz `flashcards` usados só para estatísticas da Home, sem alterar a UX.

---

## 1. Situação ANTES da implementação

### 1.1 Comportamento na UI (inalterado na intenção)

| Elemento | Comportamento |
|----------|----------------|
| Lista de matérias | Ordenação alfabética (acentos ignorados) |
| Subtítulo do card | `"N flashcards"` (total na matéria) |
| Barra de progresso | `estudados / total` da matéria |
| Texto inferior | `"X% concluído • estudados/total cards"` |
| Toque no card | Navega para `SubtemasPage(materia)` |
| Estados vazios / loading | Mesmas mensagens e spinners |

### 1.2 Implementação técnica (problema P0-1)

**Arquivo:** `lib/screens/home_page.dart` — `HomeDashboardPage`

```dart
// ANTES — listener na coleção inteira
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('flashcards')
      .snapshots(),
  ...
)
```

**Processamento no cliente (por rebuild do listener):**

1. `_agruparMaterias(docs)` — percorre **todos** os documentos de `flashcards`.
2. Para cada matéria, filtra de novo `docs.where(materia == …)`.
3. Cruza com `users/{uid}/progresso` (`idsComProgresso.contains(doc.id)`).

**Outros streams na mesma tela (mantidos):**

- `users/{uid}.snapshots()` — perfil / `isAdmin` (AppBar).
- `users/{uid}/progresso.snapshots()` — progresso do usuário.

### 1.3 Custo Firestore estimado (ANTES)

Premissas: **N** = número de flashcards (ex.: 10 000), **M** = número de matérias (~30), **P** = documentos em `progresso` do usuário (tipicamente P ≪ N).

| Evento | Leituras (ordem de grandeza) |
|--------|------------------------------|
| Abrir Home (1ª carga do listener) | **N** |
| Cada alteração em qualquer flashcard (admin) | **N** reentregues a **todos** os clientes com Home aberta |
| Sessão 5 min na Home, 2 edições admin | **N + 2×N** |
| Por matéria (CPU local) | O(N) iterações + M × filtro O(N) |

**Exemplo (N = 10 000, 500 usuários/dia abrindo Home 1×):**

- Só aberturas: **5M leituras/dia** → ~150M/mês → **~US$ 90/mês** só nesta tela (sem contar reentregas).

### 1.4 Riscos

- Escalabilidade: inviável acima de ~5–10k cards com muitos usuários simultâneos.
- Latência: lista de matérias depende do download completo da coleção.
- Billing: pico em dias de importação em massa de flashcards.

---

## 2. Situação DEPOIS da implementação

### 2.1 Arquitetura

Nova coleção de agregação:

```
flashcards_materia_stats/{slug}
  name: string      // nome exibido da matéria
  total: int         // quantidade de flashcards
  updatedAt: timestamp
```

- **Slug:** `ContentHierarchyUtils.materiaCatalogDocId(materia)`.
- **Leitura na Home:** `flashcards_materia_stats.orderBy('name').snapshots()` → **~M documentos** (M = nº de matérias), não N.
- **Progresso do usuário:** continua `users/{uid}/progresso.snapshots()`; contagem por matéria via campo `materia` no progresso (já gravado em `TelaFlashcards.salvarProgresso`).
- **Progresso legado** (sem campo `materia`): lookup pontual `whereIn` em até 10 IDs por vez — **não** varre a coleção inteira.

**Serviço:** `lib/services/flashcard_materia_stats_service.dart`

| Método | Uso |
|--------|-----|
| `watchMateriaStats()` | Stream da Home |
| `computeEstudadosPorMateria()` | Map matéria → estudados |
| `buildHomeRows()` | Monta linhas UI (totais + %) |
| `incrementMateria` / `decrementMateria` | Mantém cache após CRUD |
| `rebuildFromFlashcards()` | Recontagem paginada (400/página) |
| `ensureSeededIfEmpty()` | Uma vez se catálogo vazio |

**Manutenção do cache:**

- `FirebaseService.adicionarCard` → `incrementMateria`
- `excluirCard` / `excluirCardsEmLote` / `excluirFlashcardsPorFiltro` → `decrementMateria`
- `importarCardsJson` → `rebuildFromFlashcards()` após importação

**Migração:** na 1ª abertura da Home, se `flashcards_materia_stats` estiver vazio → `ensureSeededIfEmpty()` executa **uma** recontagem paginada (não é listener contínuo).

### 2.2 Regras e índices

- `firestore.rules`: leitura `isSignedIn()`, escrita `isAppAdmin()`.
- `firestore.indexes.json`: índice `flashcards_materia_stats` + `name` ASC (query da Home).

### 2.3 Custo Firestore estimado (DEPOIS)

| Evento | Leituras (ordem de grandeza) |
|--------|------------------------------|
| Abrir Home (catálogo já populado) | **M** (~30) + **P** (progresso do usuário) |
| Alteração de 1 flashcard (admin) | **0** na Home dos alunos (listener não está em `flashcards`) |
| Atualização do cache | 1 doc de stats (incremento) ou rebuild admin (paginado, fora da Home) |
| Progresso legado sem `materia` | até `ceil(P_legacy/10)` queries `whereIn` pontuais |

**Mesmo exemplo (M = 30, P = 200, 500 aberturas/dia):**

- **~115k leituras/dia** → ~3,5M/mês → **~US$ 2/mês** na seção Matérias (redução **~98%** vs. cenário N=10k).

### 2.4 UX — equivalência

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Ordem das matérias | Alfabética | Alfabética (`orderBy('name')` + sort defensivo) |
| Total por matéria | Contagem em memória | Campo `total` agregado |
| Estudados | Cards com doc em `progresso` | Progresso agrupado por `materia` (+ fallback legado) |
| % e texto | `estudados/totalCards` | `row.estudados/row.total` (clamp se estudados > total) |
| Navegação | `SubtemasPage` | Igual |
| Loading / vazio | Igual | Igual |

**Nota:** progresso antigo sem `materia` pode exigir 1–N queries `whereIn` pequenas na 1ª montagem; comportamento final alinhado ao anterior após resolver matéria do card.

### 2.5 O que NÃO mudou (fora do escopo P0-1)

- `admin_materias_page.dart` ainda usa `flashcards.snapshots()` (admin).
- `CronogramaService` ainda usa `flashcards.get()` completo (P0 separado).
- `SubtemasPage` continua `where('materia', …).snapshots()` (escopo por matéria — adequado).

---

## 3. Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `lib/screens/home_page.dart` | Remove listener global; usa stats + progresso |
| `lib/services/flashcard_materia_stats_service.dart` | **Novo** |
| `lib/models/flashcard_materia_stat.dart` | **Novo** |
| `lib/core/constants/firestore_paths.dart` | `flashcardsMateriaStats` |
| `lib/utils/content_hierarchy_utils.dart` | `materiaCatalogDocId` |
| `lib/services/firebase_service.dart` | Mantém agregação no CRUD/import |
| `firestore.rules` | Regras `flashcards_materia_stats` |
| `firestore.indexes.json` | Índice `name` |
| `test/services/flashcard_materia_stats_service_test.dart` | **Novo** |

---

## 4. Deploy / operação

1. Publicar **rules** e **indexes** (`firebase deploy --only firestore:rules,firestore:indexes`).
2. Abrir a Home uma vez (como admin ou usuário) para disparar seed se o catálogo estiver vazio, **ou** rodar rebuild manual via console/admin após importação histórica.
3. Validar no console: coleção `flashcards_materia_stats` com ~M documentos e soma de `total` ≈ N.

---

## 5. Resumo

| Métrica | Antes | Depois |
|---------|-------|--------|
| Listener na Home sobre `flashcards` | Sim (N docs) | **Não** |
| Docs lidos por abertura (típico) | N + P | **M + P** |
| Reentrega a todos os alunos ao editar 1 card | Sim | **Não** |
| UX da lista Matérias | — | **Preservada** |

**P0-1:** corrigido para a Home do aluno.
