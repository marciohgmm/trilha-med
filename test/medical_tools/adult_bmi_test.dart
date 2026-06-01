import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/adult_bmi.dart';

void main() {
  group('calculateAdultBmi', () {
    test('calcula IMC e classifica como Normal', () {
      // 70 kg, 175 cm → IMC ≈ 22.9
      final result = calculateAdultBmi(weightKg: 70, heightCm: 175);
      expect(result.bmi, 22.9);
      expect(result.classification, 'Normal');
    });

    test('classifica Baixo peso', () {
      final result = calculateAdultBmi(weightKg: 50, heightCm: 175);
      expect(result.classification, 'Baixo peso');
      expect(result.bmi, lessThan(18.5));
    });

    test('classifica Sobrepeso', () {
      final result = calculateAdultBmi(weightKg: 80, heightCm: 170);
      expect(result.classification, 'Sobrepeso');
      expect(result.bmi, greaterThanOrEqualTo(25));
      expect(result.bmi, lessThan(30));
    });

    test('classifica Obesidade I', () {
      final result = calculateAdultBmi(weightKg: 90, heightCm: 170);
      expect(result.classification, 'Obesidade I');
    });

    test('classifica Obesidade III', () {
      final result = calculateAdultBmi(weightKg: 120, heightCm: 170);
      expect(result.classification, 'Obesidade III');
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
        () => calculateAdultBmi(weightKg: 70, heightCm: -10),
        throwsArgumentError,
      );
    });
  });

  group('classifyAdultBmi', () {
    test('limites OMS', () {
      expect(classifyAdultBmi(18.4), 'Baixo peso');
      expect(classifyAdultBmi(18.5), 'Normal');
      expect(classifyAdultBmi(24.9), 'Normal');
      expect(classifyAdultBmi(25.0), 'Sobrepeso');
      expect(classifyAdultBmi(29.9), 'Sobrepeso');
      expect(classifyAdultBmi(30.0), 'Obesidade I');
      expect(classifyAdultBmi(34.9), 'Obesidade I');
      expect(classifyAdultBmi(35.0), 'Obesidade II');
      expect(classifyAdultBmi(39.9), 'Obesidade II');
      expect(classifyAdultBmi(40.0), 'Obesidade III');
    });
  });
}
