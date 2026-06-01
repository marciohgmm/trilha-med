# Firebase Cloud Messaging (FCM)

## Visão geral

Push completo com registro de token no app, envio segmentado pelo **Painel Mestre → Push**, jobs agendados no backend e preferências por tipo no **Perfil**.

## Tipos de notificação

| Tipo | Origem |
|------|--------|
| `flashcard_review` | Agendado diário 09h BRT |
| `cronograma_overdue` | Agendado diário 08h BRT (itens atrasados) |
| `simulado_available` | Segundas 10h BRT |
| `live_event` | Agendado (30 min antes) + callables — **somente inscritos** (padrão) ou `platform_public` explícito |
| `subscription_renewal` | Agendado diário (vence em 7 dias) |
| `promotional` | Painel Mestre / campanhas |
| `admin_broadcast` | Painel Mestre |

## Segmentação (Painel Mestre)

- `all` — usuários com token FCM registrado
- `premium` / `free` — por assinatura ativa
- `active_7d` — ativos nos últimos 7 dias
- `subscription_expiring` — renovação em até 7 dias
- `live_event_audience` — participantes do evento + host (`live_events.pushAudience = participants`, padrão)
- `live_events.pushAudience = platform_public` — usuários ativos 7d (opt-in no formulário admin; **não** usa `all`)

## App Flutter

- `FcmService` — permissão, token, foreground local notification
- `PushPreferencesService` — `users.notificationPrefs`
- `PushNavigationHandler` — deep link ao tocar
- Perfil → seção **Notificações push**

## Cloud Functions

| Function | Papel |
|----------|--------|
| `registerFcmToken` | Salva token em `users.fcmTokens` + índice `platform_fcm_users` |
| `createPushCampaign` | Admin cria campanha → trigger envia |
| `onPushCampaignCreated` | Processa fila FCM |
| `push*Scheduled` | Digest automáticos |
| `notifyLiveEventBroadcast` | Host/admin notifica evento |

## Deploy

```bash
flutter pub get
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### Android

- Permissão `POST_NOTIFICATIONS` (API 33+)
- Canal `trilhamed_default` no manifest

### iOS

- Ativar Push no Xcode → Signing & Capabilities
- Upload da chave APNs no Firebase Console

## Coleções Firestore

- `platform_push_campaigns` — histórico de envios
- `platform_fcm_users/{userId}` — índice para segmentação
- `users/{uid}.fcmTokens` — tokens por dispositivo
- `users/{uid}.notificationPrefs` — opt-in por tipo
