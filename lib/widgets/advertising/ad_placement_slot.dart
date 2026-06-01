import 'package:flutter/material.dart';

import '../../application/advertising/advertising_campaign_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../core/advertising/advertising_enums.dart';
import '../../domain/platform/models/ad_campaign.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import 'ad_creative_renderer.dart';

/// Slot de anúncio **opt-in** — não renderiza nada até [AdvertisingFeatureFlags.placementsEnabled].
///
/// **Não integrado** nas telas de estudo por padrão.
class AdPlacementSlot extends StatelessWidget {
  const AdPlacementSlot({
    super.key,
    required this.placement,
    this.access,
    this.enabled,
    this.onCampaignTap,
  });

  final AdPlacement placement;
  final CommercialAccessSnapshot? access;
  final bool? enabled;
  final void Function(AdCampaign campaign)? onCampaignTap;

  bool get _isEnabled => enabled ?? AdvertisingFeatureFlags.placementsEnabled;

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled) {
      return const SizedBox.shrink();
    }

    final service = PlatformRegistry.instance.advertisingCampaigns;
    return StreamBuilder<List<AdCampaign>>(
      stream: service.watchForPlacement(placement, access: access),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final campaign = snap.data!.first;
        return AdCreativeRenderer(
          campaign: campaign,
          onTap: () => onCampaignTap?.call(campaign),
        );
      },
    );
  }
}

/// Referência de placements preparados (documentação em código).
abstract class AdPlacementsCatalog {
  static const prepared = [
    AdPlacement.home,
    AdPlacement.profile,
    AdPlacement.questions,
    AdPlacement.simulados,
    AdPlacement.practicalPhase,
    AdPlacement.masterAdmin,
  ];
}
