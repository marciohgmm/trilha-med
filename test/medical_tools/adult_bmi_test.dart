import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/adult_bmi.dart';

void main() {
  group('calculateAdultBmi', () {
    test('calcula IMC e classifica como Eutrofia', () {
      final result = calculateAdultBmi(weightKg: 70, heightCm: 175);
      expect(result.bmi, 22.9);
      expect(result.classification, 'Eutrofia / peso adequado');
      expect(result.category, AdultBmiCategory.eutrophic);
    });

    test('classifica Baixo peso', () {
      final result = calculateAdultBmi(weightKg: 50, heightCm: 175);
      expect(result.classification, 'Baixo peso');
      expect(result.category, AdultBmiCategory.underweight);
      expect(result.bmi, lessThan(18.5));
    });

    test('classifica Sobrepeso', () {
      final result = calculateAdultBmi(weightKg: 80, heightCm: 170);
      expect(result.classification, 'Sobrepeso');
      expect(result.category, AdultBmiCategory.overweight);
      expect(result.bmi, greaterThanOrEqualTo(25));
      expect(result.bmi, lessThan(30));
    });

    test('classifica Obesidade grau I', () {
      final result = calculateAdultBmi(weightKg: 90, heightCm: 170);
      expect(result.classification, 'Obesidade grau I');
      expect(result.category, AdultBmiCategory.obesity1);
    });

    test('classifica Obesidade grau III', () {
      final result = calculateAdultBmi(weightKg: 120, heightCm: 170);
      expect(result.classification, 'Obesidade grau III');
      expect(result.category, AdultBmiCategory.obesity3);
      expect(result.bmi, greaterThanOrEqualTo(40));
    });

    test('rejeita peso inválido', () {
      expect(
        () => calculateAdultBmi(weightKg: 0, heightCm: 170),
        throwsArgumentError,
      );
    });

    test('rejeita altura inválida', () {
      expect(
        () => calculateAdultBmi(weightKg: 70, heightCm: 30),
        throwsArgumentError,
      );
    });
  });

  group('parseAdultHeightToCm', () {
    test('interpreta centímetros', () {
      expect(parseAdultHeightToCm('175'), 175);
      expect(parseAdultHeightToCm('165,5'), 165.5);
    });

    test('interpreta metros', () {
      expect(parseAdultHeightToCm('1.75'), 175);
      expect(parseAdultHeightToCm('1,68'), closeTo(168, 0.01));
    });
  });

  group('classifyAdultBmi', () {
    test('limites OMS', () {
      expect(classifyAdultBmi(18.4), 'Baixo peso');
      expect(classifyAdultBmi(18.5), 'Eutrofia / peso adequado');
      expect(classifyAdultBmi(24.9), 'Eutrofia / peso adequado');
      expect(classifyAdultBmi(25.0), 'Sobrepeso');
      expect(classifyAdultBmi(29.9), 'Sobrepeso');
      expect(classifyAdultBmi(30.0), 'Obesidade grau I');
      expect(classifyAdultBmi(34.9), 'Obesidade grau I');
      expect(classifyAdultBmi(35.0), 'Obesidade grau II');
      expect(classifyAdultBmi(39.9), 'Obesidade grau II');
      expect(classifyAdultBmi(40.0), 'Obesidade grau III');
    });
  });

  group('adultBmiGuideFor', () {
    test('baixo peso inclui sinais de alerta', () {
      final guide = adultBmiGuideFor(AdultBmiCategory.underweight);
      expect(guide.alertSigns, isNotEmpty);
      expect(guide.conductPoints, isNotEmpty);
    });

    test('obesidade grau III inclui nota de ênfase', () {
      final guide = adultBmiGuideFor(AdultBmiCategory.obesity3);
      expect(guide.emphasisNote, isNotNull);
    });
  });
}
