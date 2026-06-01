import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/cockcroft_gault.dart';

void main() {
  group('calculateCockcroftGault', () {
    test('masculino: fórmula padrão', () {
      // (140-50)*80 / (72*1.0) = 90*80/72 = 100
      final result = calculateCockcroftGault(
        ageYears: 50,
        weightKg: 80,
        creatinineMgDl: 1.0,
        sex: CockcroftSex.male,
      );
      expect(result.clearanceMlMin, 100.0);
      expect(result.interpretation, contains('normal'));
    });

    test('feminino: resultado × 0.85', () {
      final male = calculateCockcroftGault(
        ageYears: 50,
        weightKg: 80,
        creatinineMgDl: 1.0,
        sex: CockcroftSex.male,
      );
      final female = calculateCockcroftGault(
        ageYears: 50,
        weightKg: 80,
        creatinineMgDl: 1.0,
        sex: CockcroftSex.female,
      );
      expect(female.clearanceMlMin, closeTo(male.clearanceMlMin * 0.85, 0.1));
    });

    test('interpretação redução moderada', () {
      final result = calculateCockcroftGault(
        ageYears: 60,
        weightKg: 70,
        creatinineMgDl: 1.5,
        sex: CockcroftSex.male,
      );
      expect(result.clearanceMlMin, greaterThanOrEqualTo(30));
      expect(result.clearanceMlMin, lessThan(60));
      expect(result.interpretation, contains('moderada'));
    });

    test('rejeita idade inválida', () {
      expect(
        () => calculateCockcroftGault(
          ageYears: 0,
          weightKg: 70,
          creatinineMgDl: 1.0,
          sex: CockcroftSex.male,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita creatinina inválida', () {
      expect(
        () => calculateCockcroftGault(
          ageYears: 40,
          weightKg: 70,
          creatinineMgDl: 0,
          sex: CockcroftSex.male,
        ),
        throwsArgumentError,
      );
    });
  });

  group('interpretCockcroftClearance', () {
    test('faixas clínicas', () {
      expect(interpretCockcroftClearance(95), contains('normal'));
      expect(interpretCockcroftClearance(75), contains('leve'));
      expect(interpretCockcroftClearance(45), contains('moderada'));
      expect(interpretCockcroftClearance(20), contains('grave'));
      expect(interpretCockcroftClearance(10), contains('Falência'));
    });
  });
}
