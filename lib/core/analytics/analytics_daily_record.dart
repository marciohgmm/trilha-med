import 'package:cloud_firestore/cloud_firestore.dart';

import 'analytics_events.dart';

/// Agregado diário em `platform_analytics_daily/{YYYY-MM-DD}`.
class AnalyticsDailyRecord {
  const AnalyticsDailyRecord({
    required this.dateKey,
    this.dau = 0,
    this.signups = 0,
    this.logins = 0,
    this.sessions = 0,
    this.paywallViews = 0,
    this.checkoutStarts = 0,
    this.purchases = 0,
    this.purchasesCancelled = 0,
    this.revenue = 0,
  });

  final String dateKey;
  final int dau;
  final int signups;
  final int logins;
  final int sessions;
  final int paywallViews;
  final int checkoutStarts;
  final int purchases;
  final int purchasesCancelled;
  final double revenue;

  factory AnalyticsDailyRecord.fromDoc(String id, Map<String, dynamic> data) {
    return AnalyticsDailyRecord(
      dateKey: id,
      dau: (data['dau'] as num?)?.toInt() ?? 0,
      signups: (data['signups'] as num?)?.toInt() ?? 0,
      logins: (data['logins'] as num?)?.toInt() ?? 0,
      sessions: (data['sessions'] as num?)?.toInt() ?? 0,
      paywallViews: (data['paywallViews'] as num?)?.toInt() ?? 0,
      checkoutStarts: (data['checkoutStarts'] as num?)?.toInt() ?? 0,
      purchases: (data['purchases'] as num?)?.toInt() ?? 0,
      purchasesCancelled: (data['purchasesCancelled'] as num?)?.toInt() ?? 0,
      revenue: (data['revenue'] as num?)?.toDouble() ?? 0,
    );
  }

  AnalyticsDailyRecord merge(AnalyticsDailyRecord other) {
    return AnalyticsDailyRecord(
      dateKey: dateKey,
      dau: dau + other.dau,
      signups: signups + other.signups,
      logins: logins + other.logins,
      sessions: sessions + other.sessions,
      paywallViews: paywallViews + other.paywallViews,
      checkoutStarts: checkoutStarts + other.checkoutStarts,
      purchases: purchases + other.purchases,
      purchasesCancelled: purchasesCancelled + other.purchasesCancelled,
      revenue: revenue + other.revenue,
    );
  }
}

/// Incrementos Firestore para um evento espelhado.
Map<String, dynamic> dailyIncrementsForEvent(
  String eventName,
  Map<String, Object> parameters,
) {
  final updates = <String, dynamic>{
    'updatedAt': FieldValue.serverTimestamp(),
  };

  switch (eventName) {
    case AnalyticsEvents.signUp:
      updates['signups'] = FieldValue.increment(1);
    case AnalyticsEvents.login:
      updates['logins'] = FieldValue.increment(1);
    case AnalyticsEvents.sessionStart:
      updates['sessions'] = FieldValue.increment(1);
    case AnalyticsEvents.paywallView:
      updates['paywallViews'] = FieldValue.increment(1);
    case AnalyticsEvents.checkoutStart:
      updates['checkoutStarts'] = FieldValue.increment(1);
    case AnalyticsEvents.purchaseApproved:
      updates['purchases'] = FieldValue.increment(1);
      final amount = parameters[AnalyticsParams.amount];
      if (amount is num) {
        updates['revenue'] = FieldValue.increment(amount);
      }
    case AnalyticsEvents.purchaseCancelled:
      updates['purchasesCancelled'] = FieldValue.increment(1);
  }

  return updates;
}

String analyticsDayKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

List<String> analyticsDayKeysForLastDays(int days, {DateTime? now}) {
  final end = now ?? DateTime.now();
  return List.generate(days, (i) {
    final d = end.subtract(Duration(days: days - 1 - i));
    return analyticsDayKey(d);
  });
}

AnalyticsDailyRecord sumDailyRecords(
  Iterable<AnalyticsDailyRecord> records,
) {
  var acc = const AnalyticsDailyRecord(dateKey: 'sum');
  for (final r in records) {
    acc = acc.merge(r);
  }
  return acc;
}
