import '../../../core/base/firestore_entity.dart';

import '../enums/platform_enums.dart';



/// Parceria B2B (`platform_partnerships`).

class Partnership implements FirestoreEntity {

  @override

  final String id;

  final String name;

  final String contactEmail;

  final PartnershipStatus status;

  final double revenueSharePercent;

  final List<String> allowedPlanIds;

  final DateTime? startsAt;

  final DateTime? endsAt;

  final String? logoUrl;

  final String? linkUrl;

  final String? promoCouponCode;

  final Map<String, dynamic> metadata;



  const Partnership({

    required this.id,

    required this.name,

    required this.contactEmail,

    this.status = PartnershipStatus.draft,

    this.revenueSharePercent = 0,

    this.allowedPlanIds = const [],

    this.startsAt,

    this.endsAt,

    this.logoUrl,

    this.linkUrl,

    this.promoCouponCode,

    this.metadata = const {},

  });



  factory Partnership.fromDoc(String id, Map<String, dynamic> d) {

    return Partnership(

      id: id,

      name: d['name']?.toString() ?? '',

      contactEmail: d['contactEmail']?.toString() ?? '',

      status: PartnershipStatus.fromKey(d['status']?.toString()),

      revenueSharePercent: (d['revenueSharePercent'] as num?)?.toDouble() ?? 0,

      allowedPlanIds: (d['allowedPlanIds'] as List?)

              ?.map((e) => e.toString())

              .toList() ??

          const [],

      startsAt: FirestoreDates.from(d['startsAt']),

      endsAt: FirestoreDates.from(d['endsAt']),

      logoUrl: d['logoUrl']?.toString(),

      linkUrl: d['linkUrl']?.toString(),

      promoCouponCode: d['promoCouponCode']?.toString(),

      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),

    );

  }



  @override

  Map<String, dynamic> toMap() => {

        'name': name,

        'contactEmail': contactEmail,

        'status': status.key,

        'revenueSharePercent': revenueSharePercent,

        'allowedPlanIds': allowedPlanIds,

        if (startsAt != null) 'startsAt': FirestoreDates.to(startsAt),

        if (endsAt != null) 'endsAt': FirestoreDates.to(endsAt),

        if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,

        if (linkUrl != null && linkUrl!.isNotEmpty) 'linkUrl': linkUrl,

        if (promoCouponCode != null && promoCouponCode!.isNotEmpty)

          'promoCouponCode': promoCouponCode,

        if (metadata.isNotEmpty) 'metadata': metadata,

      };

}

