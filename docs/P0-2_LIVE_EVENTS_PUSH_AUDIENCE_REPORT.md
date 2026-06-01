# P0-2 — Push de Live Events (público correto)

**Data:** 2026-05-19  
**Escopo:** `pushLiveEventsScheduled`, `notifyLiveEventBroadcast`, segmentação FCM  
**Objetivo:** notificar apenas **participantes inscritos** (padrão) ou **público configurado explicitamente** — eliminar `resolveAudience("all")` em eventos ao vivo.

---

## 1. Situação ANTES da implementação

### 1.1 Pontos afetados

| Origem | Arquivo | Chamada problemática |
|--------|---------|----------------------|
| Lembrete 30 min antes | `functions/src/push/scheduled.ts` | `resolveAudience("all", PUSH_TYPES.liveEvent, { eventId })` |
| Host inicia / encerra | `functions/src/push/callables.ts` → `notifyLiveEventBroadcast` | `resolveAudience("all", …)` |

### 1.2 Comportamento real

Mesmo com `eventId` na query, o segmento **`all`** ignorava participantes e carregava até **5.000** documentos de `platform_fcm_users`, depois para cada UID:

- 1× leitura `users/{uid}`
- tokens FCM

**Resultado:** push de lembrete ou “evento ao vivo” para **toda a base com token**, não só inscritos.

### 1.3 Impacto

| Dimensão | Efeito |
|----------|--------|
| **UX** | Spam; usuários não inscritos recebiam “Evento começa em breve” |
| **Custo Firestore** | Por envio: ~5k reads `fcmUsers` + ~5k reads `users` + N tokens |
| **FCM** | Multicast para milhares de tokens por evento |
| **Reputação** | Desinstalações, denúncias de notificação indevida |

**Exemplo (1 evento/dia, 3.000 FCM):** ~**10k+ leituras Firestore** só na resolução de audiência + 3.000 notificações — **por evento**, não por inscrito.

### 1.4 Campo de configuração

O modelo `LiveEventModel` **não** tinha `pushAudience`. Não havia forma de marcar divulgação ampla de forma explícita.

---

## 2. Situação DEPOIS da implementação

### 2.1 Modelo de dados

Novo campo em `live_events`:

| Campo | Valores | Padrão |
|-------|---------|--------|
| `pushAudience` | `participants` \| `platform_public` | `participants` |

- **`participants`:** `live_events/{id}/participants` + `hostId` (se ainda não estiver entre participantes).
- **`platform_public`:** configurado **explicitamente** na criação do evento (admin) → segmento `active_7d` (usuários com atividade em 7 dias + pref `live_event`), **nunca** `all`.

Eventos legados sem campo → tratados como **`participants`**.

### 2.2 Backend (Cloud Functions)

**Novo em `segmentation.ts`:**

- `liveEventPushSegmentFromEvent(pushAudience)` — mapeia campo → segmento.
- `resolveLiveEventPushAudience(eventId, eventData)` — API única para live push.
- Guard em `resolveAudience`: se `pushType === live_event` e `segment === all` → redireciona para `live_event_audience` + log de aviso (protege campanhas admin mal configuradas).

**Alterações:**

- `scheduled.ts` → `resolveLiveEventPushAudience(doc.id, data)`; se 0 tokens, marca `pushReminderSent` e não envia spam vazio.
- `callables.ts` → `notifyLiveEventBroadcast` usa a mesma resolução; retorna `audience` no JSON.

### 2.3 App Flutter (admin)

- Enum `LiveEventPushAudience` em `live_event_models.dart`.
- `createEvent(..., pushAudience: …)` persiste o campo.
- Formulário admin: switch **“Notificações push amplas”** (opt-in para `platform_public`).

**UX do aluno:** inalterada (inscrição, play, eliminação). Só muda **quem recebe push** — alinhado à expectativa.

### 2.4 Matriz de destinatários

| Cenário | Antes | Depois |
|---------|-------|--------|
| Lembrete 30 min, 50 inscritos | ~3.000 tokens | **~50 + host** |
| Broadcast host, `participants` | ~3.000 tokens | **inscritos + host** |
| Evento com `platform_public` | ~3.000 (via `all`) | **até 3.000 ativos 7d** com pref (explícito) |
| Campanha Painel `all` + tipo `live_event` | `all` | **`live_event_audience`** (se `eventId`) |

### 2.5 Custo estimado (DEPOIS)

| Cenário | Leituras audiência (ordem) |
|---------|----------------------------|
| Lembrete, 50 inscritos | 50 participants + 50 users + tokens |
| Lembrete, 0 inscritos | ~1 query participants → **0 envios** |
| `platform_public` explícito | ≤3.000 fcmUsers (7d) + filtro prefs |

**Redução típica:** **~95–99%** leituras e notificações vs. `all` para eventos com dezenas de inscritos.

---

## 3. Testes

`functions/test/push.test.mjs`:

- `liveEventPushSegmentFromEvent` → default `live_event_audience`
- `platform_public` → `active_7d`, **não** `all`

```bash
cd functions && npm test
```

---

## 4. Deploy

```bash
cd functions && npm run build
firebase deploy --only functions:pushLiveEventsScheduled,functions:notifyLiveEventBroadcast
```

(ou deploy completo de `functions`).

App Flutter: publicar build com campo `pushAudience` no admin (compatível com eventos antigos).

---

## 5. Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `functions/src/push/constants.ts` | `LIVE_EVENT_PUSH_AUDIENCE` |
| `functions/src/push/segmentation.ts` | `resolveLiveEventPushAudience`, guard `all` |
| `functions/src/push/scheduled.ts` | Sem `all` |
| `functions/src/push/callables.ts` | Sem `all` |
| `functions/test/push.test.mjs` | Testes de segmento |
| `lib/models/live_event_models.dart` | Enum + campo |
| `lib/services/live_event_service.dart` | Persistência |
| `lib/screens/admin/admin_live_event_form_page.dart` | Switch explícito |

---

## 6. Resumo

| Item | Status |
|------|--------|
| Eliminar `resolveAudience("all")` em live scheduled | ✅ |
| Eliminar `resolveAudience("all")` em broadcast callable | ✅ |
| Público padrão = participantes + host | ✅ |
| Público amplo só com `platform_public` explícito | ✅ |
| Guard contra `all` + tipo `live_event` | ✅ |
| Relatório antes/depois | ✅ (este documento) |

**P0-2:** corrigido.
