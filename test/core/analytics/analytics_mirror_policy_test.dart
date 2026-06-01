import 'package:flutter_application_1/core/analytics/analytics_events.dart';
import 'package:flutter_application_1/core/analytics/analytics_daily_record.dart';
import 'package:flutter_application_1/core/analytics/analytics_mirror_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsMirrorPolicy', () {
    test('espelha eventos críticos de negócio', () {
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.login), isTrue);
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.signUp), isTrue);
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.paywallView), isTrue);
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.checkoutStart), isTrue);
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.purchaseApproved), isTrue);
      expect(AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.purchaseCancelled), isTrue);
    });

    test('não espelha eventos de alta frequência', () {
      expect(
        AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.flashcardStudyStart),
        isFalse,
      );
      expect(
        AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.questionsStudyStart),
        isFalse,
      );
      expect(
        AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.screenView),
        isFalse,
      );
      expect(
        AnalyticsMirrorPolicy.shouldMirrorToFirestore(AnalyticsEvents.purchasePending),
        isFalse,
      );
    });
  });

  group('dailyIncrementsForEvent', () {
    test('purchase_approved incrementa revenue', () {
      final m = dailyIncrementsForEvent(
        AnalyticsEvents.purchaseApproved,
        {AnalyticsParams.amount: 49.9},
      );
      expect(m.containsKey('purchases'), isTrue);
      expect(m.containsKey('revenue'), isTrue);
    });
  });

  group('sumDailyRecords', () {
    test('soma campos numéricos', () {
      final total = sumDailyRecords([
        const AnalyticsDailyRecord(dateKey: '2026-05-01', signups: 2, revenue: 10),
        const AnalyticsDailyRecord(dateKey: '2026-05-02', signups: 3, revenue: 20),
      ]);
      expect(total.signups, 5);
      expect(total.revenue, 30);
    });
  });
}
