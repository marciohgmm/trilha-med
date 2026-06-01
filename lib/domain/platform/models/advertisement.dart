import '../../../core/base/firestore_entity.dart';
import '../enums/platform_enums.dart';

/// Propaganda / slot publicitário (`platform_advertisements`).
class Advertisement implements FirestoreEntity {
  @override
  final String id;
  final String title;
  final AdvertisementPlacement placement;
  final String imageUrl;
  final String? targetUrl;
  final int priority;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int impressions;
  final int clicks;
  final String? partnershipId;

  const Advertisement({
    required this.id,
    required this.title,
    required this.placement,
    this.imageUrl = '',
    this.targetUrl,
    this.priority = 0,
    this.isActive = false,
    this.startsAt,
    this.endsAt,
    this.impressions = 0,
    this.clicks = 0,
    this.partnershipId,
  });

  factory Advertisement.fromDoc(String id, Map<String, dynamic> d) {
    return Advertisement(
      id: id,
      title: d['title']?.toString() ?? '',
      placement: AdvertisementPlacement.fromKey(d['placement']?.toString()),
      imageUrl: d['imageUrl']?.toString() ?? '',
      targetUrl: d['targetUrl']?.toString(),
      priority: (d['priority'] as num?)?.toInt() ?? 0,
      isActive: d['isActive'] as bool? ?? false,
      startsAt: FirestoreDates.from(d['startsAt']),
      endsAt: FirestoreDates.from(d['endsAt']),
      impressions: (d['impressions'] as num?)?.toInt() ?? 0,
      clicks: (d['clicks'] as num?)?.toInt() ?? 0,
      partnershipId: d['partnershipId']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'placement': placement.key,
        'imageUrl': imageUrl,
        if (targetUrl != null) 'targetUrl': targetUrl,
        'priority': priority,
        'isActive': isActive,
        if (startsAt != null) 'startsAt': FirestoreDates.to(startsAt),
        if (endsAt != null) 'endsAt': FirestoreDates.to(endsAt),
        'impressions': impressions,
        'clicks': clicks,
        if (partnershipId != null) 'partnershipId': partnershipId,
      };
}
