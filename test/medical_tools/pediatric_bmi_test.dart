import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/pediatric_bmi.dart';
import 'package:flutter_application_1/domain/medical_tools/pediatric_bmi_cdc_table.dart';

void main() {
  group('parsePediatricAgeMonths', () {
    test('anos sem meses extras', () {
      expect(
        parsePediatricAgeMonths(yearsText: '10', monthsText: ''),
        120,
      );
    });

    test('anos e meses', () {
      expect(
        parsePediatricAgeMonths(yearsText: '5', monthsText: '6'),
        66,
      );
    });

    test('rejeita meses inválidos', () {
      expect(
        parsePediatricAgeMonths(yearsText: '5', monthsText: '12'),
        isNull,
      );
    });
  });

  group('calculatePediatricBmi', () {
    test('calcula IMC com uma casa decimal', () {
      final result = calculatePediatricBmi(
        weightKg: 32,
        heightCm: 140,
        ageMonths: 120,
        sex: PediatricBiologicalSex.male,
      );
      expect(result.bmi, closeTo(16.3, 0.1));
    });

    test('menor de 2 anos não classifica por percentil', () {
      final result = calculatePediatricBmi(
        weightKg: 12,
        heightCm: 85,
        ageMonths: 18,
        sex: PediatricBiologicalSex.female,
      );
      expect(result.isUnderAgeTwo, isTrue);
      expect(result.estimatedPercentile, isNull);
      expect(result.category, isNull);
      expect(result.hasPercentileClassification, isFalse);
    });

    test('classifica eutrofia para IMC próximo da mediana (10 anos, menino)', () {
      final result = calculatePediatricBmi(
        weightKg: 32,
        heightCm: 140,
        ageMonths: 120,
        sex: PediatricBiologicalSex.male,
      );
      expect(result.hasPercentileClassification, isTrue);
      expect(result.category, PediatricBmiCategory.eutrophic);
      expect(result.estimatedPercentile, greaterThan(5));
      expect(result.estimatedPercentile, lessThan(85));
    });

    test('obesidade grave por IMC >= 35', () {
      final result = calculatePediatricBmi(
        weightKg: 70,
        heightCm: 140,
        ageMonths: 120,
        sex: PediatricBiologicalSex.male,
      );
      expect(result.bmi, greaterThanOrEqualTo(35));
      expect(result.category, PediatricBmiCategory.severeObesity);
    });

    test('rejeita idade acima de 19 anos', () {
      expect(
        () => calculatePediatricBmi(
          weightKg: 70,
          heightCm: 175,
          ageMonths: 240,
          sex: PediatricBiologicalSex.male,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita peso inválido', () {
      expect(
        () => calculatePediatricBmi(
          weightKg: 0,
          heightCm: 140,
          ageMonths: 120,
          sex: PediatricBiologicalSex.male,
        ),
        throwsArgumentError,
      );
    });
  });

  group('classifyPediatricBmiFromPercentile', () {
    test('limites de percentil', () {
      expect(
        classifyPediatricBmiFromPercentile(4.9, bmi: 14, p95: 21),
        PediatricBmiCategory.underweight,
      );
      expect(
        classifyPediatricBmiFromPercentile(5, bmi: 16, p95: 21),
        PediatricBmiCategory.eutrophic,
      );
      expect(
        classifyPediatricBmiFromPercentile(94.9, bmi: 20, p95: 21),
        PediatricBmiCategory.overweight,
      );
      expect(
        classifyPediatricBmiFromPercentile(96, bmi: 22, p95: 21),
        PediatricBmiCategory.obesity,
      );
    });

    test('obesidade grave por 120% do P95', () {
      expect(
        classifyPediatricBmiFromPercentile(96, bmi: 26, p95: 21),
        PediatricBmiCategory.severeObesity,
      );
    });
  });

  group('estimateBmiPercentileFromAnchors', () {
    test('interpola entre marcos', () {
      final anchor = interpolateCdcAnchors(
        PediatricBiologicalSex.male,
        120,
      );
      final p = estimateBmiPercentileFromAnchors(16.4, anchor);
      expect(p, closeTo(50, 15));
    });
  });
}
