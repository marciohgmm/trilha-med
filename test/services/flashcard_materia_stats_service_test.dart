import 'package:flutter_application_1/models/flashcard_materia_stat.dart';
import 'package:flutter_application_1/services/flashcard_materia_stats_service.dart';
import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentHierarchyUtils.materiaCatalogDocId', () {
    test('gera slug estável', () {
      expect(
        ContentHierarchyUtils.materiaCatalogDocId('Clínica Médica'),
        ContentHierarchyUtils.materiaCatalogDocId('clinica medica'),
      );
    });
  });

  group('FlashcardMateriaStatsService.buildHomeRows', () {
    test('combina totais e estudados com clamp', () {
      final service = FlashcardMateriaStatsService();
      final rows = service.buildHomeRows(
        stats: const [
          FlashcardMateriaStat(id: 'a', name: 'Cardiologia', total: 10),
          FlashcardMateriaStat(id: 'b', name: 'Pediatria', total: 5),
        ],
        estudadosPorMateria: {
          'Cardiologia': 3,
          'Pediatria': 99,
        },
      );

      expect(rows.length, 2);
      expect(rows[0].materia, 'Cardiologia');
      expect(rows[0].estudados, 3);
      expect(rows[0].progresso, 0.3);
      expect(rows[1].estudados, 5);
      expect(rows[1].progresso, 1.0);
    });
  });
}
