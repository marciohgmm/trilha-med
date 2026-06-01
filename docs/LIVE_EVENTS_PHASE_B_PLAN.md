# Plano de implementação — Live Events Fase B (Host único)

**Referência:** `docs/LIVE_EVENTS_ROUND_CONTROL_ANALYSIS.md`  
**Data:** 2026-05-19

---

## Objetivo

O criador do evento (`hostId`) torna-se o único cliente que avança rodadas automaticamente; administradores mantêm override manual. Jogadores só entram, respondem e visualizam.

---

## Escopo técnico

| Incluído | Excluído |
|----------|----------|
| Campo `hostId` no modelo e Firestore | Cloud Functions |
| Guard no `LiveEventService` | Mudança de UX visual |
| Play page: timer de avanço só host/admin | Pontuação / XP |
| Rules: coordenador vs join em contadores | |
| Compatibilidade eventos sem `hostId` | |

**Legado:** `hostId` ausente → apenas **admin** pode avançar/encerrar no cliente; `startEvent` grava `hostId` do iniciador.

---

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `lib/models/live_event_models.dart` | `hostId`, `isHost()`, `toMap`/`fromDoc` |
| `lib/services/live_event_service.dart` | `createEvent`, guards, `startEvent` |
| `lib/screens/live_events/live_event_play_page.dart` | Avanço só host/admin |
| `firestore.rules` | `live_events` + `participants` |
| `docs/LIVE_EVENTS_PHASE_B.md` | Documentação final + CF + testes |

---

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Evento live antigo sem host trava para alunos | Admin usa dashboard ou `startEvent` define host |
| Rules bloqueiam join | `isLiveEventJoinUpdate()` só contadores |
| Admin não listado não passa rules | `isAppAdmin()` alinhado a rules existentes |
| Host offline | Admin assume via dashboard (já é coordenador) |

---

## Ordem de deploy

1. Deploy **app** (hostId + guards cliente)  
2. Deploy **firestore.rules**  
3. Validar checklist em `docs/LIVE_EVENTS_PHASE_B.md`
