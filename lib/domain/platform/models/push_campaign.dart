import '../../../core/base/firestore_entity.dart';

/// Campanha push (`platform_push_campaigns`).
class PushCampaign implements FirestoreEntity {
  @override
  final String id;
  final String title;
  final String body;
  final String type;
  final String audienceSegment;
  final String? eventId;
  final String status;
  final int sentCount;
  final int failureCount;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? sentAt;

  const PushCampaign({
    required this.id,
    required this.title,
    this.body = '',
    required this.type,
    required this.audienceSegment,
    this.eventId,
    this.status = 'queued',
    this.sentCount = 0,
    this.failureCount = 0,
    this.createdBy,
    this.createdAt,
    this.sentAt,
  });

  factory PushCampaign.fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) {
      return PushCampaign(id: id, title: '', type: '', audienceSegment: 'all');
    }
    return PushCampaign(
      id: id,
      title: d['title']?.toString() ?? '',
      body: d['body']?.toString() ?? '',
      type: d['type']?.toString() ?? '',
      audienceSegment: d['audienceSegment']?.toString() ?? 'all',
      eventId: d['eventId']?.toString(),
      status: d['status']?.toString() ?? 'queued',
      sentCount: (d['sentCount'] as num?)?.toInt() ?? 0,
      failureCount: (d['failureCount'] as num?)?.toInt() ?? 0,
      createdBy: d['createdBy']?.toString(),
      createdAt: FirestoreDates.from(d['createdAt']),
      sentAt: FirestoreDates.from(d['sentAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        'audienceSegment': audienceSegment,
        if (eventId != null) 'eventId': eventId,
        'status': status,
        'sentCount': sentCount,
        'failureCount': failureCount,
        if (createdBy != null) 'createdBy': createdBy,
      };
}
