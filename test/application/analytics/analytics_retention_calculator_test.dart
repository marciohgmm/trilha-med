import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/application/analytics/analytics_retention_calculator.dart';

void main() {
  group('AnalyticsRetentionCalculator', () {
    final now = DateTime(2025, 6, 15);

    test('cohort vazio retorna zeros', () {
      final r = AnalyticsRetentionCalculator.compute(
        signupsByUser: {},
        sessionsByUserDay: {},
        now: now,
      );
      expect(r.cohortSize, 0);
      expect(r.d1, 0);
    });

    test('D1 conta retorno no dia seguinte ao cadastro', () {
      final signup = DateTime(2025, 6, 10);
      final day1 = DateTime(2025, 6, 11);
      final r = AnalyticsRetentionCalculator.compute(
        signupsByUser: {'u1': signup, 'u2': signup},
        sessionsByUserDay: {
          'u1': {AnalyticsRetentionCalculator.dayKey(day1)},
          'u2': {},
        },
        now: now,
      );
      expect(r.cohortSize, 2);
      expect(r.d1, 50);
    });

    test('dayKey formata YYYY-MM-DD', () {
      expect(
        AnalyticsRetentionCalculator.dayKey(DateTime(2025, 3, 5)),
        '2025-03-05',
      );
    });
  });
}
