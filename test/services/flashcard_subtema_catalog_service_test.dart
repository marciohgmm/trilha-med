import 'package:flutter_application_1/models/flashcard_subtema_catalog_entry.dart';
import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentHierarchyUtils.subtemaCatalogDocId', () {
    test('gera slug estável para o par matéria/subtema', () {
      expect(
        ContentHierarchyUtils.subtemaCatalogDocId('Cardiologia', 'IAM'),
        ContentHierarchyUtils.subtemaCatalogDocId('cardiologia', 'iam'),
      );
    });

    test('pares distintos geram ids distintos', () {
      final a = ContentHierarchyUtils.subtemaCatalogDocId('Cardiologia', 'IAM');
      final b =
          ContentHierarchyUtils.subtemaCatalogDocId('Cardiologia', 'IC');
      expect(a, isNot(equals(b)));
    });
  });

  group('FlashcardSubtemaCatalogEntry', () {
    test('toCronogramaPair expõe materia e subtema', () {
      const entry = FlashcardSubtemaCatalogEntry(
        id: 'x',
        materia: 'Pediatria',
        subtema: 'Vacinas',
        cardCount: 3,
      );
      expect(entry.toCronogramaPair(), {
        'materia': 'Pediatria',
        'subtema': 'Vacinas',
      });
    });
  });
}
