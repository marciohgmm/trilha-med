import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/weight_dose.dart';

void main() {
  group('calculateWeightDose', () {
    test('exemplo: 20 kg × 10 mg/kg = 200 mg', () {
      final result = calculateWeightDose(weightKg: 20, dosePerKgMg: 10);
      expect(result.totalDoseMg, 200);
      expect(result.formulaText, contains('20.0 kg'));
      expect(result.formulaText, contains('10.00 mg/kg'));
      expect(result.formulaText, contains('200.00 mg'));
    });

    test('calcula dose com decimais', () {
      final result = calculateWeightDose(weightKg: 12.5, dosePerKgMg: 7.5);
      expect(result.totalDoseMg, 93.75);
    });

    test('rejeita peso inválido', () {
      expect(
        () => calculateWeightDose(weightKg: 0, dosePerKgMg: 10),
        throwsArgumentError,
      );
    });

    test('rejeita dose inválida', () {
      expect(
        () => calculateWeightDose(weightKg: 20, dosePerKgMg: -5),
        throwsArgumentError,
      );
    });
  });
}
