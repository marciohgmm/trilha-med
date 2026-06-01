import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/revalida_official/revalida_performance_calculator.dart';
import 'package:flutter_application_1/models/questao_model.dart';

QuestaoModel _q({
  required String id,
  required String materia,
  required String subtema,
  required String corretaId,
}) {
  return QuestaoModel(
    id: id,
    temaId: 't1',
    temaSlug: 't1',
    materiaId: 'm1',
    materia: materia,
    tema: 'Tema',
    subtema: subtema,
    flashcardId: 'fc_$id',
    enunciado: 'Enunciado $id',
    alternativas: const [
      QuestaoAlternativa(id: 'a', texto: 'A'),
      QuestaoAlternativa(id: 'b', texto: 'B'),
    ],
    corretaId: corretaId,
    explicacaoGeral: '',
    explicacaoCorreta: '',
    explicacoesErradas: const {},
    justificativasPorAlternativa: const {},
    dificuldade: 'media',
    status: 'ativa',
    tags: const [],
    ativo: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    ordem: 0,
  );
}

void main() {
  group('RevalidaPerformanceCalculator', () {
    test('calcula score e breakdown por matéria/subtema', () {
      final questoes = [
        _q(id: '1', materia: 'Clínica', subtema: 'Cardio', corretaId: 'a'),
        _q(id: '2', materia: 'Clínica', subtema: 'Cardio', corretaId: 'a'),
        _q(id: '3', materia: 'Pediatria', subtema: 'Vacinas', corretaId: 'b'),
      ];

      final result = RevalidaPerformanceCalculator().calculate(
        questoes: questoes,
        selectedAlternativaByQuestaoId: {
          '1': 'a',
          '2': 'b',
          '3': 'b',
        },
        durationSeconds: 3600,
      );

      expect(result.correctAnswers, 2);
      expect(result.wrongAnswers, 1);
      expect(result.unanswered, 0);
      expect(result.scorePercent, closeTo(66.7, 0.1));
      expect(result.subjectBreakdown.length, 2);
      expect(result.subtopicBreakdown.length, 2);
    });

    test('top 5 fraquezas e fortes', () {
      final questoes = List.generate(
        6,
        (i) => _q(
          id: '$i',
          materia: 'M',
          subtema: 'S$i',
          corretaId: 'a',
        ),
      );

      final result = RevalidaPerformanceCalculator().calculate(
        questoes: questoes,
        selectedAlternativaByQuestaoId: {
          '0': 'b',
          '1': 'b',
          '2': 'a',
          '3': 'a',
          '4': 'a',
          '5': 'a',
        },
        durationSeconds: 100,
      );

      expect(result.topWeaknesses, isNotEmpty);
      expect(result.topStrengths, isNotEmpty);
      expect(result.topWeaknesses.first.wrong, greaterThan(0));
    });
  });

  group('selectBalancedQuestions', () {
    test('distribui equilibrado entre matérias', () {
      final pool = {
        'A': List.generate(
          60,
          (i) => _q(id: 'a$i', materia: 'A', subtema: 's', corretaId: 'a'),
        ),
        'B': List.generate(
          60,
          (i) => _q(id: 'b$i', materia: 'B', subtema: 's', corretaId: 'a'),
        ),
      };

      final selected = selectBalancedQuestions(poolByMateria: pool, total: 100);
      expect(selected.length, 100);

      final countA = selected.where((q) => q.materia == 'A').length;
      final countB = selected.where((q) => q.materia == 'B').length;
      expect(countA, 50);
      expect(countB, 50);
    });
  });

  group('computeBalancedMateriaQuotas', () {
    test('100 questões em 4 matérias = 25 cada', () {
      final q = computeBalancedMateriaQuotas(
        materias: ['A', 'B', 'C', 'D'],
        total: 100,
      );
      expect(q.values.every((v) => v == 25), isTrue);
    });
  });
}
