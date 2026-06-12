import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/body_surface_area.dart';

void main() {
  group('calculateBodySurfaceAreaMosteller', () {
    test('exemplo 170 cm e 70 kg ≈ 1,82 m²', () {
      final result = calculateBodySurfaceAreaMosteller(
        weightKg: 70,
        heightCm: 170,
      );
      expect(result.product, 11900);
      expect(result.dividedBy3600, closeTo(3.3056, 0.001));
      expect(result.bsaM2, 1.82);
      expect(result.steps.length, 5);
      expect(result.steps.last.value, '1,82 m²');
    });

    test('formata com 2 casas decimais', () {
      final result = calculateBodySurfaceAreaMosteller(
        weightKg: 65,
        heightCm: 165,
      );
      expect(result.bsaFormatted.split('.').last.length, 2);
    });

    test('rejeita peso inválido', () {
      expect(
        () => calculateBodySurfaceAreaMosteller(weightKg: 0, heightCm: 170),
        throwsArgumentError,
      );
    });

    test('rejeita altura inválida', () {
      expect(
        () => calculateBodySurfaceAreaMosteller(weightKg: 70, heightCm: 20),
        throwsArgumentError,
      );
    });
  });

  group('parseHeightCmOnly', () {
    test('aceita vírgula decimal', () {
      expect(parseHeightCmOnly('165,5'), 165.5);
    });
  });
}
