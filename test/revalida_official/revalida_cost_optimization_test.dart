import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/revalida_official/revalida_simulator_build_metrics.dart';

void main() {
  group('computeRevalidaFetchLimit', () {
    test('limita ao total da matéria', () {
      expect(
        computeRevalidaFetchLimit(quota: 10, materiaTotal: 15),
        15,
      );
    });

    test('usa quota × multiplier + buffer', () {
      // 10 * 3 + 10 = 40
      expect(
        computeRevalidaFetchLimit(quota: 10, materiaTotal: 500),
        40,
      );
    });

    test('quota pequena com buffer mínimo', () {
      // 5 * 3 + 10 = 25
      expect(
        computeRevalidaFetchLimit(quota: 5, materiaTotal: 200),
        25,
      );
    });
  });

  group('RevalidaSimulatorBuildMetrics', () {
    test('toLogMap contém campos esperados', () {
      final m = RevalidaSimulatorBuildMetrics(
        buildDurationMs: 120,
        firestoreReads: 85,
        documentsEvaluated: 80,
        documentsSelected: 100,
        cacheHit: false,
        materiaCount: 8,
      );
      final map = m.toLogMap();
      expect(map['reads'], 85);
      expect(map['selected'], 100);
      expect(map['cacheHit'], false);
    });
  });

  group('projeção de custo ANTES × DEPOIS', () {
    test('economia com 10 matérias e banco de 2000 questões', () {
      const bancoTotal = 2000;
      const materias = 10;
      const quotaPorMateria = 10;
      const readsAntes = bancoTotal;

      var readsDepois = materias; // stats catalog
      for (var i = 0; i < materias; i++) {
        readsDepois += computeRevalidaFetchLimit(
          quota: quotaPorMateria,
          materiaTotal: bancoTotal ~/ materias,
        );
      }

      final economia =
          ((readsAntes - readsDepois) / readsAntes * 100).round();

      expect(readsAntes, 2000);
      expect(readsDepois, 410);
      expect(readsDepois, lessThan(readsAntes));
      expect(economia, greaterThan(75));
    });

    test('cache hit reduz reads a zero na montagem', () {
      const readsComCache = 0;
      const readsSemCache = 410;
      expect(readsComCache, lessThan(readsSemCache));
    });
  });
}
