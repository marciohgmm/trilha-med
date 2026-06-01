# Auditoria crítica — Painel Mestre (`permission-denied` em todos os módulos)

**Data:** 2026-05-19  
**Modo:** Somente leitura — **nenhum código alterado**  
**Sintoma:** Todos os 11 módulos exibem `FirebaseError: [code=permission-denied]`

---

## Veredito executivo

| Hipótese | Compatível com “**todos** os módulos” incluindo Vendedores, Afiliados, Planos e Cupons? |
|----------|----------------------------------------------------------------------------------------|
| **(a) Rules `platform_*` não publicadas no Firebase** | **Sim — causa #1** |
| **(b) Conta sem privilégios (`isAppAdmin`)** | **Parcial** — explica Dashboard, Usuários, Assinaturas, Parceiros, Ads, Audit; **não** explica Vendedores/Afiliados se rules estiverem publicadas |
| **(c) Divergência RBAC × Firestore** | **Parcial** — libera UI do painel, nega dados admin; **não** explica falha em `platform_sellers` (só exige login) |
| **(d) Coleção sem regra no repo** | **Não** — todas as coleções usadas **têm** `match` em `firestore.rules` local |
| **(e) Auth nulo / projeto Firebase errado** | **Sim — causa #2** — nega **tudo**, inclusive leituras `isSignedIn()` |

**Causa raiz mais provável (cenário “100% dos módulos”):**

1. **`firestore.rules` do repositório não foi deployado** no projeto `revalida-cards` (bloco linhas 394–494 ausente em produção → *default deny* em todas as `platform_*`), **ou**
2. Requisições Firestore sem **`request.auth`** válido (sessão expirada, Auth/Firestore em projetos diferentes).

**Causa raiz secundária (se Vendedores/Afiliados funcionarem, mas admin não):**

3. Conta passa no **RBAC cliente** mas **não satisfaz `isAppAdmin()`** no Firestore (sem `admins/{uid}`, sem `users.isAdmin`, não founder) — divergência **(c)** + S1.

---

## 1. Auditoria de `firestore.rules` (arquivo local)

Arquivo: `firestore.rules` (497 linhas). Funções admin relevantes:

```javascript
isFounder()      → email token == marciohgmm@gmail.com
isListedAdmin()  → exists(admins/{auth.uid})
isAdmin()        → isFounder() || isListedAdmin()
isAppAdmin()     → isAdmin() || (exists(users/{auth.uid}) && users.isAdmin == true)
```

**Observação crítica:** `isAppAdmin()` **não lê** `users.rbacRoles`. RBAC do app **não existe** nas rules.

### 1.1 Regras das coleções `platform_*` (presentes no repo)

| Coleção | Linhas | `read` | `write` |
|---------|--------|--------|---------|
| `platform_subscription_plans` | 418–422 | `isSignedIn()` **e** (`isAppAdmin()` **ou** `isActive == true`) | `isAppAdmin()` |
| `platform_subscriptions` | 424–428 | `isAppAdmin()` **ou** dono (`userId == auth.uid`) | idem |
| `platform_payments` | 431–435 | `isAppAdmin()` **ou** dono | `isAppAdmin()` |
| `platform_sellers` | 438–441 | **`isSignedIn()`** (via `isPlatformCatalogReader`) | `isAppAdmin()` |
| `platform_affiliates` | 443–446 | **`isSignedIn()`** | `isAppAdmin()` |
| `platform_coupons` | 448–451 | `isSignedIn()` **e** (`isAppAdmin()` **ou** `isActive == true`) | `isAppAdmin()` |
| `platform_partnerships` | 454–457 | **`isAppAdmin()` only** | `isAppAdmin()` |
| `platform_advertisements` | 459–463 | `isSignedIn()` **e** (`isAppAdmin()` **ou** `isActive == true`) | `isAppAdmin()` |
| `platform_audit_logs` | 465–468 | **`isAppAdmin()`** | `create: isSignedIn()` |
| `platform_rbac_permissions` | 486–489 | **`isSignedIn()`** | `isAppAdmin()` |
| `platform_rbac_roles` | 491–494 | **`isSignedIn()`** | `isAppAdmin()` |

### 1.2 Regras legadas usadas pelo Painel Mestre

| Coleção | Linhas | Impacto no painel |
|---------|--------|-------------------|
| `users` | 96–104 | Listagem/count → exige **`isAppAdmin()`** (S1) |
| `admins` | 88–90 | Count total → exige **`isAdmin()`** (founder ou `admins/{uid}` — **não** `users.isAdmin` sozinho) |

**Conclusão item (d):** No repositório **não há** coleção do Painel Mestre sem `match`. Se falha em produção, é **deploy** ou **auth**, não ausência no arquivo local.

---

## 2. Coleções utilizadas pelo Painel Mestre

| Coleção | Usada em |
|---------|----------|
| `users` | Dashboard (count/where), Usuários (stream), RBAC (`resolveContext`), Configurações |
| `admins` | Dashboard (`count`) |
| `platform_subscriptions` | Dashboard, Assinaturas |
| `platform_subscription_plans` | Dashboard (receita), Planos |
| `platform_payments` | Dashboard (count pending) |
| `platform_sellers` | Dashboard, Vendedores |
| `platform_affiliates` | Dashboard, Afiliados |
| `platform_coupons` | Dashboard, Cupons |
| `platform_partnerships` | Parceiros |
| `platform_advertisements` | Propagandas |
| `platform_audit_logs` | Dashboard, Auditoria, shell (create) |
| `platform_rbac_roles` | `RbacService.loadCatalog` (shell + Configurações) |
| `platform_rbac_permissions` | idem |

Todas as 10 coleções `platform_*` solicitadas no escopo **existem** em `FirestorePaths` e **possuem** rules no repo.

---

## 3. Queries por módulo (exatas)

### 3.1 Shell — `master_admin_shell.dart` (`_bootstrap`)

| Ordem | Operação | Coleção | Arquivo origem |
|-------|----------|---------|----------------|
| 1 | `get()` ×2 + seed batch opcional | `platform_rbac_roles`, `platform_rbac_permissions` | `firestore_rbac_repository.dart` |
| 2 | `get()` | `users/{auth.uid}` | `rbac_service.dart` |
| 3 | `set()` merge opcional | `users/{auth.uid}` (`rbacRoles`) | `admin_legacy_compat.dart` |
| 4 | `set()` create | `platform_audit_logs` | `platform_audit_service.dart` |

Erros de seed (4) são **engolidos** (`loadCatalog` → fallback). Erros em (1) read exigem `isSignedIn` — falham só sem auth ou sem rules.

### 3.2 Dashboard — `_AdminDashboardRepo.loadSnapshot()`

Ordem **sequencial** (primeira falha aborta o `try` da página):

| # | Query | Coleção | `_safeCount`? |
|---|-------|---------|---------------|
| **1** | **`users.count().get()`** | `users` | **Não — aborta** |
| 2 | `users.where(updatedAt ≥ 30d).count()` | `users` | Sim → 0 |
| 3 | `users.where(createdAt ≥ 30d).count()` | `users` | Sim → 0 |
| **4** | **`admins.count().get()`** | `admins` | **Não — aborta** |
| 5 | `users.where(isAdmin==true).count()` | `users` | Sim → 0 |
| 6–12 | counts diversos | `platform_sellers`, `platform_affiliates`, `platform_subscriptions`, `platform_payments`, `platform_coupons` | Sim → 0 |
| **13** | **`platform_audit_logs.orderBy(...).limit(8).get()`** | `platform_audit_logs` | **Não — aborta** |
| 14 | subs + plans get | `platform_subscriptions`, `platform_subscription_plans` | try/catch → 0 |

### 3.3 Demais módulos

| Módulo | Query | Coleção |
|--------|-------|---------|
| Usuários | `users.limit(100).snapshots()` | `users` |
| Assinaturas | `platform_subscriptions.limit(80).snapshots()` | `platform_subscriptions` |
| Planos | `platform_subscription_plans.where(isActive==true).orderBy(sortOrder).snapshots()` | `platform_subscription_plans` |
| Vendedores | `platform_sellers.snapshots()` (sem filtro) | `platform_sellers` |
| Afiliados | `platform_affiliates.snapshots()` | `platform_affiliates` |
| Cupons | `platform_coupons.where(isActive==true).snapshots()` | `platform_coupons` |
| Parceiros | `platform_partnerships.snapshots()` | `platform_partnerships` |
| Propagandas | `platform_advertisements.limit(50).snapshots()` | `platform_advertisements` |
| Auditoria | `platform_audit_logs.orderBy(createdAt desc).limit(100).snapshots()` | `platform_audit_logs` |
| Configurações | `resolveContext()` + opcional `loadCatalog(forceRefresh)` | `users/{uid}`, `platform_rbac_*` |

---

## 4. PRIMEIRA consulta que falha ao abrir o Dashboard

### 4.1 Identificação no código

**Arquivo:** `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart`  
**Classe:** `_AdminDashboardRepo`  
**Método:** `loadSnapshot()`  
**Linha:** 406  

```dart
final totalUsers = (await usersCol.count().get()).count ?? 0;
```

**Query:** agregação `count()` na coleção **`users`** (sem filtro de `userId`).

### 4.2 Regra que bloqueia

**Arquivo:** `firestore.rules`  
**Match:** `match /users/{userId}` (linha 96)  
**Allow read:** `isOwner(userId) || isAppAdmin()` (linha 98)

### 4.3 Condição não satisfeita

Para `count()` em toda a coleção `users`, o Firestore exige que o caller possa ler **documentos além do próprio**. Isso só ocorre se:

```javascript
isAppAdmin() == true
```

Ou seja, **pelo menos uma** destas deve ser verdadeira **no token/request**:

| Condição | Campo avaliado |
|----------|----------------|
| Founder | `request.auth.token.email.lower() == 'marciohgmm@gmail.com'` |
| Listado em admins | `exists(/admins/{auth.uid})` |
| Flag legada | `get(/users/{auth.uid}).data.isAdmin == true` |

Se **nenhuma** for verdadeira:

- `isOwner(userId)` só vale para `users/{auth.uid}` — insuficiente para count global.
- **Resultado:** `permission-denied` na **primeira linha** do dashboard.

### 4.4 Se o usuário **é** `isAppAdmin()` e ainda falha no Dashboard

A próxima candidata a falhar (não abortada por `_safeCount`) seria:

| # | Query | Rule | Condição |
|---|-------|------|----------|
| 4 | `admins.count()` | L89: `auth.uid == adminId \|\| isAdmin()` | Falha se só `users.isAdmin` **sem** doc em `admins/` |
| 8 | `platform_subscriptions.count()` | L425 | Falha se não `isAppAdmin()` |
| 13 | `platform_audit_logs.get()` | L466 | Falha se não `isAppAdmin()` |

---

## 5. Por que “TODOS” os módulos falham — árvore de decisão

```
Todos os módulos com permission-denied?
│
├─ SIM inclui Vendedores + Afiliados + Planos + Cupons
│   │
│   ├─ (a) Rules platform_* NÃO deployadas → default deny em TODAS
│   ├─ (e) request.auth == null → isSignedIn() false em TODAS
│   └─ (e) App aponta para outro projectId que rules antigas
│
└─ NÃO — só módulos “admin-only” falham
    │
    └─ (b)+(c) isAppAdmin() false no Firestore, RBAC cliente true
        • Dashboard → users.count (1ª falha)
        • Usuários → users query S1
        • Assinaturas, Parceiros, Audit → isAppAdmin
        • Propagandas → query sem isActive (docs inativos)
        • Vendedores/Afiliados/Planos/Cupons → OK se rules deployadas
```

**Teste decisivo (1 minuto no Console):** autenticado como o mesmo usuário, Rules Playground:

- `read` em `/platform_sellers/x` → se **deny** com user logado → **(a)** ou **(e)**.
- `read` em `/platform_sellers/x` → **allow**, mas `read` count em `users` → **deny** → **(b)/(c)**.

---

## 6. Divergência RBAC × AdminAccessService × firestore.rules

### 6.1 Quem decide o quê

| Camada | Serviço | Critério “admin / pode ver módulo” | Usado para |
|--------|---------|-------------------------------------|------------|
| Entrada admin | `AdminAccessService` → `PermissionContext.canAccessAdminPanel` | founder, `listedInAdmins`, `users.isAdmin`, papéis `admin`/`masterAdmin`, `admin.panel.access` | `AdminGate` |
| Módulo | `RbacGate` + `PermissionChecker.hasKey` | founder → tudo; senão chaves do catálogo / matrix fallback | Menu e rotas |
| **Dados** | **Firestore rules** | **`isAppAdmin()`** (founder, `admins/`, `users.isAdmin`) | **Todas as queries** |

### 6.2 Matriz de divergência

| Sinal no app | `canAccessAdminPanel` | `isAppAdmin()` Firestore | Efeito |
|--------------|----------------------|--------------------------|--------|
| `rbacRoles: ['admin']` only | **true** (papel admin) | **false** | Painel abre; **Firestore nega** módulos admin |
| `users.isAdmin` only | **true** | **true** | Firestore admin OK; **`admins.count()`** no Dashboard pode falhar (usa `isAdmin()` ≠ `isAppAdmin`) |
| `admins/{uid}` only | **true** | **true** | Alinhado |
| Founder email | **true** | **true** | Alinhado |
| Aluno comum | false | false | Nem entra no painel |

### 6.3 Dependências do Painel Mestre

| Dependência | Cliente (UI) | Firestore (dados) |
|-------------|--------------|-------------------|
| `admins/{uid}` | `listedInAdmins` → admin panel | `isAdmin()` + `isAppAdmin()` |
| `users.isAdmin` | `legacyAdmin`, flag no contexto | **`isAppAdmin()`** |
| `users.rbacRoles` | Papéis + permissões UI | **Ignorado** |
| Founder email | Bypass total UI | `isFounder()` / `isAppAdmin()` |

**Conclusão:** O Painel Mestre **depende de Firestore admin** para dados, **não** de `rbacRoles`. RBAC só controla **quais abas aparecem**; não substitui `isAppAdmin()`.

---

## 7. Análise módulo a módulo — query, rule, condição

| Módulo | Query representativa | Rule (linha) | Condição que falha (não-admin) | Classificação |
|--------|---------------------|--------------|--------------------------------|---------------|
| **Dashboard** | `users.count()` (#1) | L98 | `isAppAdmin()` false | **(b)/(c)** |
| **Usuários** | `users.limit(100).snapshots()` | L98 | Query cross-user sem `isAppAdmin()` | **(b)/(c)** S1 |
| **Assinaturas** | `platform_subscriptions.snapshots()` | L425 | Não é dono de todas | **(b)/(c)** |
| **Planos** | `...where(isActive==true)` | L419–420 | Se rules ausentes: **(a)**; senão passa com login | **(a)** ou OK |
| **Vendedores** | `platform_sellers.snapshots()` | L439 | Só falha se `!isSignedIn()` ou **(a)** | **(a)/(e)** |
| **Afiliados** | idem affiliates | L444 | idem | **(a)/(e)** |
| **Cupons** | `where(isActive==true)` | L449–450 | idem Planos | **(a)** ou OK |
| **Parceiros** | `partnerships.snapshots()` | L455 | `isAppAdmin()` false | **(b)/(c)** |
| **Propagandas** | `advertisements.limit(50)` | L460–461 | Admin ou doc `isActive`; query sem filtro | **(b)/(c)** |
| **Auditoria** | `audit_logs.snapshots()` | L466 | `isAppAdmin()` false | **(b)/(c)** |
| **Configurações** | `users/{uid}.get()` + RBAC get | L98, L487 | UI raramente mostra erro; reload seed **write** nega não-admin | UI OK; write **(b)** |

---

## 8. Classificação final da causa raiz

### Cenário A — **100% dos módulos** (incl. Vendedores, Afiliados)

| ID | Causa | Probabilidade |
|----|-------|---------------|
| **a** | **`firestore.rules` com bloco `platform_*` (L394–494) não publicado** | **Alta** |
| **e** | Auth ausente nas requests Firestore / projeto errado | Média |

**Evidência:** Com rules publicadas, `platform_sellers` **allow read: if isSignedIn()`** — coleção vazia retorna lista vazia, **não** `permission-denied`.

### Cenário B — Só módulos “pesados” falham; catálogo OK

| ID | Causa |
|----|-------|
| **b** | Conta sem `admins/{uid}`, sem `users.isAdmin`, não founder |
| **c** | RBAC concedeu `admin` via `rbacRoles` ou matrix fallback, Firestore não reconhece |

**Primeira falha:** Dashboard linha 406 — `users.count()`.

### Cenário C — Founder/admin real, ainda falha tudo

| ID | Causa |
|----|-------|
| **a** | Rules produção ≠ repo (deploy pendente) |
| **e** | Token email não propagado (`isFounder()` false) enquanto app trata como founder por hardcode |

---

## 9. Plano de correção (não implementado)

### P0 — Confirmar diagnóstico (Console, sem código)

1. Firebase → Firestore → **Rules** → verificar se existem matches `platform_sellers`, `platform_rbac_roles`, etc.
2. **Rules Playground** com UID do operador:
   - `get /platform_sellers/test`
   - `get /users/{uid}` (próprio)
   - Simular list/count em `users`
3. **Request monitor** → abrir Dashboard → capturar **primeira** linha negada (esperado: `users` aggregate).

### P1 — Operacional / dados

| Se causa | Ação |
|----------|------|
| **(a)** | `firebase deploy --only firestore:rules` (+ indexes se necessário) |
| **(b)** | Garantir `admins/{uid}` **ou** `users/{uid}.isAdmin: true` para operadores do Painel Mestre |
| **(c)** | Documentar: `rbacRoles` **não** substitui `isAppAdmin`; sincronizar grant admin com `admins` + flag |
| Founder | Confirmar e-mail no token Auth = `marciohgmm@gmail.com` |

### P2 — Código (futuro, após confirmar P0)

| Item | Objetivo |
|------|----------|
| Guard `isAppAdmin` antes de queries admin | Falhar cedo com mensagem clara vs `FirebaseError` |
| Dashboard: `_safeCount` também em `users.count()` e `admins.count()` | Degradar métricas em vez de crash |
| Alinhar `isAdmin()` → `isAppAdmin()` na rule `admins` read | Corrigir count admins para flag-only |
| Propagandas: `where('isActive', true)` | Alinhar com rule L460 |
| Remover `ensureDefaultSeed` do path do aluno | Seed só deploy admin |
| Opcional: rules helper `isRbacAdmin()` | Só se produto exigir parity RBAC↔Firestore |

---

## 10. Checklist de verificação do operador

Preencher com o usuário que vê o erro:

```text
[ ] projectId do app = revalida-cards (firebase.json / firebase_options)
[ ] Rules publicadas contêm "platform_sellers" ?
[ ] Auth UID: _______________
[ ] Auth email: _______________
[ ] Firestore admins/{uid} exists: sim / não
[ ] Firestore users/{uid}.isAdmin: sim / não
[ ] Firestore users/{uid}.rbacRoles: _______________
[ ] Vendedores falha igual Dashboard: sim / não
[ ] Request monitor — 1ª denial path: _______________
```

---

## 11. Referências

| Artefato | Caminho |
|----------|---------|
| Rules | `firestore.rules` L28–35, L88–104, L418–494 |
| Dashboard queries | `lib/infrastructure/firestore/platform/firestore_platform_repositories.dart` L398–480 |
| RBAC resolve | `lib/application/rbac/rbac_service.dart` L36–109 |
| Admin access | `lib/application/admin/admin_access_service.dart` L25–57 |
| Permission context | `lib/core/permissions/permission_context.dart` L47–52 |
| Módulos UI | `lib/screens/master_admin/modules/` |

---

**Fim da auditoria crítica — nenhuma alteração de código foi aplicada.**
