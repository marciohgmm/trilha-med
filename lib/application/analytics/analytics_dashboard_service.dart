import 'package:cloud_firestore/cloud_firestore.dart';



import '../../core/analytics/analytics_daily_record.dart';

import '../../core/analytics/analytics_event_record.dart';

import '../../core/analytics/analytics_events.dart';

import '../../core/constants/firestore_paths.dart';

import '../../domain/platform/models/analytics_dashboard_snapshot.dart';

import 'analytics_retention_calculator.dart';



/// Dashboard admin a partir de agregados diários + eventos brutos mínimos (retenção).

class AnalyticsDashboardService {

  AnalyticsDashboardService({FirebaseFirestore? firestore})

      : _db = firestore ?? FirebaseFirestore.instance;



  final FirebaseFirestore _db;



  Future<AnalyticsDashboardSnapshot> loadSnapshot() async {

    final now = DateTime.now();

    final dayKeys30 = analyticsDayKeysForLastDays(30, now: now);

    final dayKeys7 = dayKeys30.sublist(dayKeys30.length - 7);



    final dailyRecords = await _loadDailyRecords(dayKeys30);

    final sum30 = sumDailyRecords(dailyRecords);

    final sum7 = sumDailyRecords(

      dailyRecords.where((r) => dayKeys7.contains(r.dateKey)),

    );



    final todayKey = analyticsDayKey(now);

    final yesterdayKey = analyticsDayKey(now.subtract(const Duration(days: 1)));



    final dauToday = await _countActiveUsers(todayKey);

    final dauYesterday = await _countActiveUsers(yesterdayKey);



    final retention = await _computeRetention(now);



    final conversionRate = sum30.checkoutStarts > 0

        ? sum30.purchases / sum30.checkoutStarts * 100

        : 0.0;



    return AnalyticsDashboardSnapshot(

      signUpsLast7Days: sum7.signups,

      signUpsLast30Days: sum30.signups,

      loginsLast7Days: sum7.logins,

      sessionsLast7Days: sum7.sessions,

      dailyActiveUsersToday: dauToday,

      dailyActiveUsersYesterday: dauYesterday,

      retentionD1: retention.d1,

      retentionD7: retention.d7,

      retentionD30: retention.d30,

      cohortSizeForRetention: retention.cohortSize,

      paywallViewsLast30Days: sum30.paywallViews,

      checkoutStartsLast30Days: sum30.checkoutStarts,

      purchasesApprovedLast30Days: sum30.purchases,

      purchasesCancelledLast30Days: sum30.purchasesCancelled,

      checkoutConversionRate: conversionRate,

      revenueLast30Days: sum30.revenue,

      featureUsageLast30Days: const {},

      couponUsageLast30Days: const {},

      affiliateConversionsLast30Days: const {},

      sellerConversionsLast30Days: const {},

      generatedAt: now,

    );

  }



  Future<List<AnalyticsDailyRecord>> _loadDailyRecords(

    List<String> dayKeys,

  ) async {

    if (dayKeys.isEmpty) return [];



    final refs = dayKeys

        .map((k) => _db.collection(FirestorePaths.platformAnalyticsDaily).doc(k))

        .toList();



    final snaps = await Future.wait(refs.map((r) => r.get()));

    return snaps

        .where((s) => s.exists)

        .map((s) => AnalyticsDailyRecord.fromDoc(s.id, s.data()!))

        .toList();

  }



  Future<int> _countActiveUsers(String dayKey) async {

    try {

      final snap = await _db

          .collection(FirestorePaths.platformAnalyticsDaily)

          .doc(dayKey)

          .collection('active_users')

          .count()

          .get();

      return snap.count ?? 0;

    } catch (_) {

      return 0;

    }

  }



  Future<RetentionResult> _computeRetention(DateTime now) async {

    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final ts30 = Timestamp.fromDate(thirtyDaysAgo);



    final snap = await _db

        .collection(FirestorePaths.platformAnalyticsEvents)

        .where('eventName', whereIn: [

          AnalyticsEvents.sessionStart,

          AnalyticsEvents.signUp,

        ])

        .where('createdAt', isGreaterThanOrEqualTo: ts30)

        .orderBy('createdAt', descending: true)

        .limit(2000)

        .get();



    final events = snap.docs

        .map((d) => AnalyticsEventRecord.fromDoc(d.id, d.data()))

        .toList();



    final signupByUser = <String, DateTime>{};

    final sessionsByUserDay = <String, Set<String>>{};



    for (final e in events) {

      final uid = e.userId;

      if (uid == null || uid.isEmpty) continue;



      if (e.eventName == AnalyticsEvents.signUp) {

        signupByUser[uid] = e.createdAt;

      }

      if (e.eventName == AnalyticsEvents.sessionStart) {

        final day = AnalyticsRetentionCalculator.dayKey(e.createdAt);

        sessionsByUserDay.putIfAbsent(uid, () => {}).add(day);

      }

    }



    return AnalyticsRetentionCalculator.compute(

      signupsByUser: signupByUser,

      sessionsByUserDay: sessionsByUserDay,

      now: now,

    );

  }

}


