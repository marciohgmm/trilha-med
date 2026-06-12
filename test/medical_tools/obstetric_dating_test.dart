import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/obstetric_dating.dart';

void main() {
  final ref = DateTime(2026, 5, 19);
  final lmp = DateTime(2025, 8, 12);

  group('calculateDueDateByLmp', () {
    test('DPP com ciclo de 28 dias = DUM + 280 dias', () {
      final result = calculateDueDateByLmp(
        lmp: lmp,
        cycleLengthDays: 28,
        referenceDate: ref,
      );
      expect(result.dueDate, DateTime(2026, 5, 19));
      expect(result.cycleAdjustmentDays, 0);
      expect(result.gestationalAgeToday.totalDays, 280);
    });

    test('ajusta DPP para ciclo de 35 dias', () {
      final result = calculateDueDateByLmp(
        lmp: lmp,
        cycleLengthDays: 35,
        referenceDate: ref,
      );
      expect(result.cycleAdjustmentDays, 7);
      expect(result.dueDate, DateTime(2026, 5, 26));
    });

    test('rejeita DUM futura', () {
      expect(
        () => calculateDueDateByLmp(
          lmp: DateTime(2026, 6, 1),
          referenceDate: ref,
        ),
        throwsArgumentError,
      );
    });
  });

  group('calculateDueDateByUltrasound', () {
    test('DPP = data US + dias restantes até 40 semanas', () {
      final usDate = DateTime(2025, 11, 1);
      final result = calculateDueDateByUltrasound(
        ultrasoundDate: usDate,
        gestationalWeeksAtExam: 12,
        gestationalExtraDaysAtExam: 3,
        trimester: UltrasoundTrimester.first,
        referenceDate: ref,
      );
      // 12w3d = 87 dias; restam 193 dias → DPP 2026-05-13
      expect(result.gestationalAgeAtExam.totalDays, 87);
      expect(result.dueDate, DateTime(2026, 5, 13));
    });

    test('idade gestacional hoje após US', () {
      final usDate = DateTime(2025, 11, 1);
      final result = calculateDueDateByUltrasound(
        ultrasoundDate: usDate,
        gestationalWeeksAtExam: 12,
        gestationalExtraDaysAtExam: 0,
        trimester: UltrasoundTrimester.first,
        referenceDate: ref,
      );
      expect(result.gestationalAgeToday.totalDays, greaterThan(87));
    });
  });

  group('compareDumAndUltrasound', () {
    test('calcula diferença em dias', () {
      final lmpRes = calculateDueDateByLmp(
        lmp: lmp,
        referenceDate: ref,
      );
      final usRes = calculateDueDateByUltrasound(
        ultrasoundDate: DateTime(2025, 11, 1),
        gestationalWeeksAtExam: 12,
        gestationalExtraDaysAtExam: 3,
        trimester: UltrasoundTrimester.first,
        referenceDate: ref,
      );
      final cmp = compareDumAndUltrasound(
        lmpResult: lmpRes,
        ultrasoundResult: usRes,
      );
      expect(cmp, isNotNull);
      expect(cmp!.differenceDays, -6);
    });
  });

  group('formatGestationalAge', () {
    test('formata semanas e dias', () {
      expect(
        formatGestationalAge(const GestationalAge(totalDays: 87)),
        '12 semanas e 3 dias',
      );
      expect(
        formatGestationalAge(const GestationalAge(totalDays: 14)),
        '2 semanas',
      );
    });
  });

  group('parseGestationalExtraDays', () {
    test('vazio equivale a zero', () {
      expect(parseGestationalExtraDays(''), 0);
    });
    test('rejeita mais de 6 dias', () {
      expect(parseGestationalExtraDays('7'), isNull);
    });
  });
}
