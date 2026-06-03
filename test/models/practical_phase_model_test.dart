import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/practical_phase_model.dart';

void main() {
  group('PracticalPhaseModel', () {
    test('fromMap e toMap roundtrip', () {
      final now = DateTime(2025, 6, 1);
      final map = {
        'title': 'Estação Cardio',
        'slug': 'cardio',
        'description': 'Desc',
        'category': 'Clínica',
        'specialty': 'Cardiologia',
        'difficulty': 'Avançado',
        'thumbnailUrl': 'https://example.com/t.jpg',
        'isActive': true,
        'isPublished': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'createdBy': 'admin',
        'order': 2,
        'sections': [],
        'attachments': [],
      };

      final model = PracticalPhaseModel.fromMap('id1', map);
      expect(model.title, 'Estação Cardio');
      expect(model.visibleToStudents, isTrue);
      expect(model.displayStatus, 'Publicado');

      final out = model.toMap();
      expect(out['title'], 'Estação Cardio');
      expect(out['isPublished'], isTrue);
    });

    test('requiresPremium default false no fromMap legado', () {
      final model = PracticalPhaseModel.fromMap('id', {
        'title': 'T',
        'slug': 's',
        'description': '',
        'category': '',
        'specialty': '',
        'difficulty': '',
        'thumbnailUrl': '',
        'isActive': true,
        'isPublished': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': '',
      });
      expect(model.requiresPremium, isFalse);
    });

    test('requiresPremium roundtrip no toMap', () {
      final model = PracticalPhaseModel(
        id: 'x',
        title: 'Premium',
        slug: 'premium',
        description: '',
        category: '',
        specialty: '',
        difficulty: '',
        thumbnailUrl: '',
        isActive: true,
        isPublished: true,
        requiresPremium: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
      );
      expect(model.toMap()['requiresPremium'], isTrue);
    });

    test('visibleToStudents exige ativo e publicado', () {
      final model = PracticalPhaseModel(
        id: 'x',
        title: 'T',
        slug: 's',
        description: '',
        category: '',
        specialty: '',
        difficulty: '',
        thumbnailUrl: '',
        isActive: true,
        isPublished: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
      );
      expect(model.visibleToStudents, isFalse);
      expect(model.displayStatus, 'Rascunho');
    });

    test('stationCount soma itens das seções', () {
      final model = PracticalPhaseModel(
        id: 'x',
        title: 'T',
        slug: 's',
        description: '',
        category: '',
        specialty: '',
        difficulty: '',
        thumbnailUrl: '',
        isActive: true,
        isPublished: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
        sections: [
          PracticalPhaseSection(
            id: 'sec1',
            title: 'S1',
            description: '',
            items: [
              PracticalPhaseItem(id: 'i1', title: 'A', content: ''),
              PracticalPhaseItem(id: 'i2', title: 'B', content: ''),
            ],
          ),
        ],
      );
      expect(model.stationCount, 2);
    });
  });
}
