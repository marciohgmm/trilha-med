# Sistema de Anúncios, Campanhas e Parceiros

**Projeto:** revalida-cards  
**Princípio:** estrutura administrável pronta; **exibição desligada** por padrão (`AdvertisingFeatureFlags.placementsEnabled = false`).

Relatório prévio: [ADVERTISING_PRE_AUDIT.md](./ADVERTISING_PRE_AUDIT.md)

---

## 1. Visão geral

| Camada | Responsabilidade |
|--------|------------------|
| `platform_ad_campaigns` | Campanhas (criativo, segmentação, métricas, ciclo de vida) |
| `platform_partnerships` | Parceiros (logo, link, cupom, datas) |
| `platform_advertisements` | Legado — mantido para compatibilidade |
| `AdvertisingCampaignService` | Resolve campanhas por placement + audiência |
| `AdCampaignAdminService` | CRUD, pausar, encerrar |
| `AdPlacementSlot` | Widget opt-in (não usado em telas de estudo) |

---

## 2. Ciclo de vida da campanha

| Estado | Condição |
|--------|----------|
| **Rascunho** | `adminStatus: draft` |
| **Agendada** | `adminStatus: active` e `startsAt` no futuro |
| **Ativa** | `adminStatus: active` e dentro do período |
| **Pausada** | `adminStatus: paused` |
| **Encerrada** | `adminStatus: ended` |
| **Expirada** | `endsAt` no passado |

Getter: `AdCampaign.lifecycle`

---

## 3. Tipos de anúncio (`AdFormat`)

| Key | Label |
|-----|-------|
| `banner` | Banner |
| `native_card` | Card nativo |
| `popup` | Popup |
| `fullscreen` | Tela cheia |
| `institutional` | Aviso institucional |

Renderização: `AdCreativeRenderer` (quando placements habilitados).

---

## 4. Placements preparados (`AdPlacement`)

| Key | Tela |
|-----|------|
| `home` | Home |
| `profile` | Perfil |
| `questions` | Questões |
| `simulados` | Simulados |
| `practical_phase` | Fase Prática |
| `master_admin` | Painel Mestre |

**Não integrados** em `home_page`, `questoes_page`, etc. Use:

```dart
AdPlacementSlot(
  placement: AdPlacement.home,
  enabled: false, // padrão global também false
)
```

---

## 5. Segmentação (`AdAudienceSegment`)

| Segmento | Critério |
|----------|----------|
| `all` | Todos |
| `premium` | `CommercialAccessSnapshot.hasPremiumAccess` |
| `free` | Não premium |
| `beta_tester` | Entitlement `beta_tester` |
| `seller` | Entitlement `seller_access` |
| `affiliate` | Entitlement `affiliate_access` |

---

## 6. Métricas

Campos em `AdCampaign`:

- `impressions`, `clicks`, `conversions`, `estimatedRevenue`
- **CTR:** `campaign.ctr` (calculado)
- Incremento: `AdCampaignRepository.incrementImpressions/Clicks/Conversions` (futuro tracking)

Dashboard: `AdCampaignDashboardSnapshot` + Painel **Dashboard campanhas**.

---

## 7. Parceiros (`platform_partnerships`)

Campos estendidos:

- `logoUrl`, `linkUrl`, `promoCouponCode`
- `startsAt`, `endsAt`
- `name`, `contactEmail`, `status`, `revenueSharePercent`

CRUD: Painel Mestre → **Parceiros** (`partnership.manage`).

---

## 8. Painel Mestre

| Módulo | Permissão | Funções |
|--------|-----------|---------|
| **Campanhas** | `campaign.manage` | Criar, editar, pausar, retomar, encerrar, excluir |
| **Dashboard campanhas** | `campaign.manage` | Ativas, agendadas, encerradas + métricas |
| **Parceiros** | `partnership.manage` | CRUD parceiros |
| **Propagandas (legado)** | `ad.manage` | CRUD `platform_advertisements` |

---

## 9. RBAC

| Permissão | Key |
|-----------|-----|
| Anúncios legado | `ad.manage` |
| Parceiros | `partnership.manage` |
| Campanhas | `campaign.manage` |

Incluídas em `masterAdmin` e `admin` em `RolePermissionMatrix`.

---

## 10. Firestore

### Coleção `platform_ad_campaigns`

Documento exemplo:

```json
{
  "name": "Parceiro X — Março",
  "format": "native_card",
  "placements": ["home", "profile"],
  "audienceSegment": "free",
  "adminStatus": "active",
  "startsAt": "...",
  "endsAt": "...",
  "title": "Oferta especial",
  "imageUrl": "https://...",
  "targetUrl": "https://...",
  "partnerName": "Parceiro X",
  "promoCouponCode": "PARCEIRO10",
  "impressions": 0,
  "clicks": 0,
  "conversions": 0,
  "estimatedRevenue": 500,
  "priority": 10
}
```

### Rules

- Leitura: usuário autenticado + campanha `adminStatus == active` (ou admin)
- Escrita: admin

Deploy: `firebase deploy --only firestore:rules,firestore:indexes`

---

## 11. Ativar exibição (futuro)

1. Definir `AdvertisingFeatureFlags.placementsEnabled = true` (ou por placement `enabled: true`)
2. Inserir `AdPlacementSlot` na tela desejada
3. Passar `CommercialAccessSnapshot` para segmentação correta
4. Chamar `incrementImpressions` / `incrementClicks` no tap (integração futura)

**Não fazer** em telas de estudo até decisão de produto.

---

## 12. Arquivos principais

```
lib/core/advertising/advertising_enums.dart
lib/domain/platform/models/ad_campaign.dart
lib/application/advertising/advertising_campaign_service.dart
lib/application/advertising/ad_campaign_admin_service.dart
lib/widgets/advertising/ad_placement_slot.dart
lib/widgets/advertising/ad_creative_renderer.dart
lib/widgets/master_admin/master_admin_campaign_forms.dart
lib/screens/master_admin/modules/master_admin_campaigns_page.dart
lib/screens/master_admin/modules/master_admin_campaign_dashboard_page.dart
lib/core/constants/firestore_paths.dart  → platformAdCampaigns
```

---

## 13. Compatibilidade

- MVP comercial / assinaturas — inalterado
- Fluxos de estudo — **sem** `AdPlacementSlot` integrado
- `platform_advertisements` — legado preservado

---

*Maio/2026*
