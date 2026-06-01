import '../../../core/advertising/advertising_enums.dart';
import '../../../core/base/firestore_entity.dart';

/// Campanha publicitária (`platform_ad_campaigns`).
class AdCampaign implements FirestoreEntity {
  @override
  final String id;
  final String name;
  final String description;
  final AdFormat format;
  final List<AdPlacement> placements;
  final AdAudienceSegment audienceSegment;
  final AdCampaignAdminStatus adminStatus;
  final DateTime? startsAt;
  final DateTime? endsAt;

  // Criativo
  final String title;
  final String? bodyText;
  final String imageUrl;
  final String? targetUrl;

  // Parceiro (denormalizado + link opcional à parceria)
  final String? partnershipId;
  final String? partnerName;
  final String? partnerLogoUrl;
  final String? promoCouponCode;

  // Métricas
  final int impressions;
  final int clicks;
  final int conversions;
  final double estimatedRevenue;
  final int priority;
  final DateTime? createdAt;

  const AdCampaign({
    required this.id,
    required this.name,
    this.description = '',
    this.format = AdFormat.banner,
    this.placements = const [],
    this.audienceSegment = AdAudienceSegment.all,
    this.adminStatus = AdCampaignAdminStatus.draft,
    this.startsAt,
    this.endsAt,
    required this.title,
    this.bodyText,
    this.imageUrl = '',
    this.targetUrl,
    this.partnershipId,
    this.partnerName,
    this.partnerLogoUrl,
    this.promoCouponCode,
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.estimatedRevenue = 0,
    this.priority = 0,
    this.createdAt,
  });

  /// CTR em percentual (0–100).
  double get ctr => impressions > 0 ? (clicks / impressions) * 100 : 0;

  /// Ciclo de vida derivado (datas + status admin).
  AdCampaignLifecycle get lifecycle {
    if (adminStatus == AdCampaignAdminStatus.draft) {
      return AdCampaignLifecycle.draft;
    }
    if (adminStatus == AdCampaignAdminStatus.paused) {
      return AdCampaignLifecycle.paused;
    }
    if (adminStatus == AdCampaignAdminStatus.ended) {
      return AdCampaignLifecycle.ended;
    }
    final now = DateTime.now();
    if (endsAt != null && now.isAfter(endsAt!)) {
      return AdCampaignLifecycle.expired;
    }
    if (startsAt != null && now.isBefore(startsAt!)) {
      return AdCampaignLifecycle.scheduled;
    }
    if (adminStatus == AdCampaignAdminStatus.active) {
      return AdCampaignLifecycle.active;
    }
    return AdCampaignLifecycle.draft;
  }

  bool get isDeliverable =>
      lifecycle == AdCampaignLifecycle.active ||
      lifecycle == AdCampaignLifecycle.scheduled;

  factory AdCampaign.fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) {
      return AdCampaign(id: id, name: '', title: '');
    }
    return AdCampaign(
      id: id,
      name: d['name']?.toString() ?? '',
      description: d['description']?.toString() ?? '',
      format: AdFormat.fromKey(d['format']?.toString()),
      placements: (d['placements'] as List?)
              ?.map((e) => AdPlacement.fromKey(e.toString()))
              .toList() ??
          const [],
      audienceSegment:
          AdAudienceSegment.fromKey(d['audienceSegment']?.toString()),
      adminStatus:
          AdCampaignAdminStatus.fromKey(d['adminStatus']?.toString()),
      startsAt: FirestoreDates.from(d['startsAt']),
      endsAt: FirestoreDates.from(d['endsAt']),
      title: d['title']?.toString() ?? '',
      bodyText: d['bodyText']?.toString(),
      imageUrl: d['imageUrl']?.toString() ?? '',
      targetUrl: d['targetUrl']?.toString(),
      partnershipId: d['partnershipId']?.toString(),
      partnerName: d['partnerName']?.toString(),
      partnerLogoUrl: d['partnerLogoUrl']?.toString(),
      promoCouponCode: d['promoCouponCode']?.toString(),
      impressions: (d['impressions'] as num?)?.toInt() ?? 0,
      clicks: (d['clicks'] as num?)?.toInt() ?? 0,
      conversions: (d['conversions'] as num?)?.toInt() ?? 0,
      estimatedRevenue: (d['estimatedRevenue'] as num?)?.toDouble() ?? 0,
      priority: (d['priority'] as num?)?.toInt() ?? 0,
      createdAt: FirestoreDates.from(d['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'format': format.key,
        'placements': placements.map((p) => p.key).toList(),
        'audienceSegment': audienceSegment.key,
        'adminStatus': adminStatus.key,
        if (startsAt != null) 'startsAt': FirestoreDates.to(startsAt),
        if (endsAt != null) 'endsAt': FirestoreDates.to(endsAt),
        'title': title,
        if (bodyText != null && bodyText!.isNotEmpty) 'bodyText': bodyText,
        'imageUrl': imageUrl,
        if (targetUrl != null) 'targetUrl': targetUrl,
        if (partnershipId != null) 'partnershipId': partnershipId,
        if (partnerName != null) 'partnerName': partnerName,
        if (partnerLogoUrl != null) 'partnerLogoUrl': partnerLogoUrl,
        if (promoCouponCode != null) 'promoCouponCode': promoCouponCode,
        'impressions': impressions,
        'clicks': clicks,
        'conversions': conversions,
        'estimatedRevenue': estimatedRevenue,
        'priority': priority,
      };

  AdCampaign copyWith({
    AdCampaignAdminStatus? adminStatus,
    int? impressions,
    int? clicks,
    int? conversions,
    double? estimatedRevenue,
  }) =>
      AdCampaign(
        id: id,
        name: name,
        description: description,
        format: format,
        placements: placements,
        audienceSegment: audienceSegment,
        adminStatus: adminStatus ?? this.adminStatus,
        startsAt: startsAt,
        endsAt: endsAt,
        title: title,
        bodyText: bodyText,
        imageUrl: imageUrl,
        targetUrl: targetUrl,
        partnershipId: partnershipId,
        partnerName: partnerName,
        partnerLogoUrl: partnerLogoUrl,
        promoCouponCode: promoCouponCode,
        impressions: impressions ?? this.impressions,
        clicks: clicks ?? this.clicks,
        conversions: conversions ?? this.conversions,
        estimatedRevenue: estimatedRevenue ?? this.estimatedRevenue,
        priority: priority,
        createdAt: createdAt,
      );
}

/// Agregação para dashboard de campanhas.
class AdCampaignDashboardSnapshot {
  final List<AdCampaign> active;
  final List<AdCampaign> scheduled;
  final List<AdCampaign> endedOrExpired;
  final int totalImpressions;
  final int totalClicks;
  final double averageCtr;
  final int totalConversions;
  final double totalEstimatedRevenue;
  final DateTime generatedAt;

  const AdCampaignDashboardSnapshot({
    this.active = const [],
    this.scheduled = const [],
    this.endedOrExpired = const [],
    this.totalImpressions = 0,
    this.totalClicks = 0,
    this.averageCtr = 0,
    this.totalConversions = 0,
    this.totalEstimatedRevenue = 0,
    required this.generatedAt,
  });

  factory AdCampaignDashboardSnapshot.fromCampaigns(List<AdCampaign> all) {
    final active = <AdCampaign>[];
    final scheduled = <AdCampaign>[];
    final endedOrExpired = <AdCampaign>[];
    var impressions = 0;
    var clicks = 0;
    var conversions = 0;
    var revenue = 0.0;

    for (final c in all) {
      impressions += c.impressions;
      clicks += c.clicks;
      conversions += c.conversions;
      revenue += c.estimatedRevenue;
      switch (c.lifecycle) {
        case AdCampaignLifecycle.active:
          active.add(c);
          break;
        case AdCampaignLifecycle.scheduled:
          scheduled.add(c);
          break;
        case AdCampaignLifecycle.ended:
        case AdCampaignLifecycle.expired:
          endedOrExpired.add(c);
          break;
        default:
          break;
      }
    }

    return AdCampaignDashboardSnapshot(
      active: active,
      scheduled: scheduled,
      endedOrExpired: endedOrExpired,
      totalImpressions: impressions,
      totalClicks: clicks,
      averageCtr: impressions > 0 ? (clicks / impressions) * 100 : 0,
      totalConversions: conversions,
      totalEstimatedRevenue: revenue,
      generatedAt: DateTime.now(),
    );
  }
}
