import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/parkland_rule.dart';

void main() {
  final burn = DateTime(2026, 5, 19, 8, 0);
  const weight = 70.0;
  const tbsa = 20.0;

  group('calculateParklandVolumeBreakdown', () {
    test('exemplo 70 kg e 20% = 5600 mL', () {
      final v = calculateParklandVolumeBreakdown(
        weightKg: weight,
        tbsaPercent: tbsa,
      );
      expect(v.total24hMl, 5600);
      expect(v.first8hMl, 2800);
      expect(v.next16hMl, 2800);
    });
  });

  group('calculateParklandResuscitation', () {
    test('2 h após queimadura — taxa na fase 8 h', () {
      final ref = burn.add(const Duration(hours: 2));
      final result = calculateParklandResuscitation(
        weightKg: weight,
        tbsaPercent: tbsa,
        burnDateTime: burn,
        referenceDateTime: ref,
      );
      expect(result.status, ParklandTimelineStatus.withinFirst8Hours);
      expect(result.firstPhasePlan.hoursRemaining, closeTo(6, 0.01));
      expect(result.firstPhasePlan.remainingMl, 2800);
      expect(result.firstPhasePlan.rateMlPerHour, closeTo(2800 / 6, 1));
    });

    test('10 h após queimadura — fase 16 h', () {
      final ref = burn.add(const Duration(hours: 10));
      final result = calculateParklandResuscitation(
        weightKg: weight,
        tbsaPercent: tbsa,
        burnDateTime: burn,
        referenceDateTime: ref,
      );
      expect(result.status, ParklandTimelineStatus.withinSecondPhase);
      expect(result.firstPhasePlan.hoursRemaining, 0);
      expect(result.secondPhasePlan.hoursRemaining, closeTo(14, 0.01));
    });

    test('desconta volume já infundido', () {
      final ref = burn.add(const Duration(hours: 1));
      final result = calculateParklandResuscitation(
        weightKg: weight,
        tbsaPercent: tbsa,
        burnDateTime: burn,
        referenceDateTime: ref,
        fluidAlreadyGivenMl: 500,
      );
      expect(result.totalRemainingMl, 5100);
      expect(result.firstPhasePlan.remainingMl, 2300);
    });

    test('após 24 h não calcula fase ativa', () {
      final ref = burn.add(const Duration(hours: 25));
      final result = calculateParklandResuscitation(
        weightKg: weight,
        tbsaPercent: tbsa,
        burnDateTime: burn,
        referenceDateTime: ref,
      );
      expect(result.isBeyond24Hours, isTrue);
      expect(result.currentRateMlPerHour, isNull);
    });

    test('rejeita % SCQ inválido', () {
      expect(
        () => calculateParklandResuscitation(
          weightKg: 70,
          tbsaPercent: 0,
          burnDateTime: burn,
        ),
        throwsArgumentError,
      );
    });
  });
}
