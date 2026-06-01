import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/revalida_official/revalida_evolution_summary.dart';
import 'package:flutter_application_1/domain/revalida_official/revalida_official_config.dart';
import 'package:flutter_application_1/models/revalida_simulation_model.dart';

void main() {
  group('RevalidaSimulationRecord', () {
    test('serialização Firestore round-trip', () {
      final record = RevalidaSimulationRecord(
        id: 'x',
        uid: 'user1',
        startedAt: DateTime(2026, 5, 1, 10),
        finishedAt: DateTime(2026, 5, 1, 14),
        durationSeconds: 7200,
        score: 72.5,
        totalQuestions: 100,
        correctAnswers: 72,
        wrongAnswers: 25,
        unanswered: 3,
        subjectBreakdown: const [
          RevalidaSubjectBreakdown(
            subject: 'Clínica',
            total: 50,
            correct: 40,
            wrong: 10,
            unanswered: 0,
          ),
        ],
        subtopicBreakdown: const [
          RevalidaSubtopicBreakdown(
            subject: 'Clínica',
            subtopic: 'Cardio',
            total: 10,
            correct: 7,
            wrong: 3,
            unanswered: 0,
          ),
        ],
        questaoIds: const ['q1', 'q2'],
        respostas: const {'q1': 'a', 'q2': 'b'},
      );

      final map = record.toFirestoreMap();
      expect(map['uid'], 'user1');
      expect(map['totalQuestions'], 100);
      expect(map['mode'], 'revalida_oficial');

      final restored = RevalidaSimulationRecord.fromDoc('doc1', map);
      expect(restored.uid, record.uid);
      expect(restored.score, record.score);
      expect(restored.subjectBreakdown.length, 1);
      expect(restored.respostas['q1'], 'a');
    });
  });

  group('summarizeRevalidaEvolution', () {
    test('calcula melhor nota, média e evolução', () {
      final records = [
        RevalidaSimulationRecord(
          id: '1',
          uid: 'u',
          startedAt: DateTime(2026, 5, 2),
          finishedAt: DateTime(2026, 5, 2),
          durationSeconds: 1000,
          score: 80,
          totalQuestions: 100,
          correctAnswers: 80,
          wrongAnswers: 20,
          unanswered: 0,
          subjectBreakdown: const [],
          subtopicBreakdown: const [],
          questaoIds: const [],
          respostas: const {},
        ),
        RevalidaSimulationRecord(
          id: '2',
          uid: 'u',
          startedAt: DateTime(2026, 5, 1),
          finishedAt: DateTime(2026, 5, 1),
          durationSeconds: 1000,
          score: 60,
          totalQuestions: 100,
          correctAnswers: 60,
          wrongAnswers: 40,
          unanswered: 0,
          subjectBreakdown: const [],
          subtopicBreakdown: const [],
          questaoIds: const [],
          respostas: const {},
        ),
      ];

      final summary = summarizeRevalidaEvolution(records);
      expect(summary.bestScore, 80);
      expect(summary.latestScore, 80);
      expect(summary.averageScore, 70);
      expect(summary.evolutionPercent, closeTo(33.3, 0.1));
    });

    test('lista vazia retorna zeros', () {
      final summary = summarizeRevalidaEvolution([]);
      expect(summary.totalSimulations, 0);
      expect(summary.bestScore, 0);
    });
  });
}
