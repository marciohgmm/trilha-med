import '../../core/advertising/advertising_enums.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../domain/platform/models/ad_campaign.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../domain/platform/repositories/platform_repository_contracts.dart';

/// Resolve campanhas elegíveis por placement e segmentação (uso futuro — opt-in).
class AdvertisingCampaignService {
  AdvertisingCampaignService({
    required AdCampaignRepository campaignRepo,
  }) : _campaignRepo = campaignRepo;

  final AdCampaignRepository _campaignRepo;

  Stream<List<AdCampaign>> watchForPlacement(
    AdPlacement placement, {
    CommercialAccessSnapshot? access,
  }) {
    return _campaignRepo.watchByPlacement(placement).map(
          (campaigns) => campaigns
              .where((c) => c.lifecycle == AdCampaignLifecycle.active)
              .where((c) => _matchesAudience(c, access))
              .toList(),
        );
  }

  Stream<AdCampaignDashboardSnapshot> watchDashboard() {
    return _campaignRepo.watchAll().map(AdCampaignDashboardSnapshot.fromCampaigns);
  }

  Future<AdCampaignDashboardSnapshot> loadDashboard() async {
    final campaigns = await _campaignRepo.watchAll().first;
    return AdCampaignDashboardSnapshot.fromCampaigns(campaigns);
  }

  bool _matchesAudience(AdCampaign campaign, CommercialAccessSnapshot? access) {
    if (campaign.audienceSegment == AdAudienceSegment.all) return true;
    if (access == null) {
      return campaign.audienceSegment == AdAudienceSegment.free;
    }
    switch (campaign.audienceSegment) {
      case AdAudienceSegment.premium:
        return access.hasPremiumAccess;
      case AdAudienceSegment.free:
        return !access.hasPremiumAccess;
      case AdAudienceSegment.betaTester:
        return access.hasKey(CommercialEntitlementKey.betaTester);
      case AdAudienceSegment.seller:
        return access.hasKey(CommercialEntitlementKey.sellerAccess);
      case AdAudienceSegment.affiliate:
        return access.hasKey(CommercialEntitlementKey.affiliateAccess);
      case AdAudienceSegment.all:
        return true;
    }
  }
}

/// Flag global — **false** por padrão; não exibe anúncios até ativação explícita.
class AdvertisingFeatureFlags {
  AdvertisingFeatureFlags._();

  static bool placementsEnabled = false;
}
