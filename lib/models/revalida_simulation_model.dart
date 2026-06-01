import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/revalida_official/revalida_official_config.dart';
import '../models/simulado_models.dart';

/// Registro persistido em `revalida_simulations`.
class RevalidaSimulationRecord {
  const RevalidaSimulationRecord({
    required this.id,
    required this.uid,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSeconds,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.unanswered,
    required this.subjectBreakdown,
    required this.subtopicBreakdown,
    required this.questaoIds,
    required this.respostas,
  });

  final String id;
  final String uid;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationSeconds;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int unanswered;
  final List<RevalidaSubjectBreakdown> subjectBreakdown;
  final List<RevalidaSubtopicBreakdown> subtopicBreakdown;
  final List<String> questaoIds;
  final Map<String, String> respostas;

  Map<String, dynamic> toFirestoreMap() => {
        'uid': uid,
        'startedAt': Timestamp.fromDate(startedAt),
        'finishedAt': Timestamp.fromDate(finishedAt),
        'durationSeconds': durationSeconds,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'unanswered': unanswered,
        'subjectBreakdown':
            subjectBreakdown.map((e) => e.toJson()).toList(),
        'subtopicBreakdown':
            subtopicBreakdown.map((e) => e.toJson()).toList(),
        'questaoIds': questaoIds,
        'respostas': respostas,
        'mode': 'revalida_oficial',
      };

  factory RevalidaSimulationRecord.fromDoc(String id, Map<String, dynamic> m) {
    final subjectRaw = m['subjectBreakdown'] as List? ?? [];
    final subtopicRaw = m['subtopicBreakdown'] as List? ?? [];
    final respostasRaw = m['respostas'] as Map? ?? {};

    return RevalidaSimulationRecord(
      id: id,
      uid: m['uid']?.toString() ?? '',
      startedAt: parseFirestoreDate(m['startedAt']) ?? DateTime.now(),
      finishedAt: parseFirestoreDate(m['finishedAt']) ?? DateTime.now(),
      durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
      score: (m['score'] as num?)?.toDouble() ?? 0,
      totalQuestions: (m['totalQuestions'] as num?)?.toInt() ?? 0,
      correctAnswers: (m['correctAnswers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (m['wrongAnswers'] as num?)?.toInt() ?? 0,
      unanswered: (m['unanswered'] as num?)?.toInt() ?? 0,
      subjectBreakdown: subjectRaw
          .map((e) =>
              RevalidaSubjectBreakdown.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtopicBreakdown: subtopicRaw
          .map((e) =>
              RevalidaSubtopicBreakdown.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      questaoIds: (m['questaoIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      respostas: respostasRaw.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
}

class RevalidaEvolutionSummary {
  const RevalidaEvolutionSummary({
    required this.totalSimulations,
    required this.bestScore,
    required this.averageScore,
    required this.latestScore,
    required this.evolutionPercent,
  });

  final int totalSimulations;
  final double bestScore;
  final double averageScore;
  final double latestScore;
  final double evolutionPercent;
}

/// Plano de estudo gerado a partir das fraquezas.
class RevalidaWeaknessStudyPlan {
  const RevalidaWeaknessStudyPlan({
    required this.weakSubtopics,
    required this.flashcardIds,
    required this.questaoIds,
    required this.subtopicLabels,
  });

  final List<RevalidaSubtopicBreakdown> weakSubtopics;
  final List<String> flashcardIds;
  final List<String> questaoIds;
  final List<String> subtopicLabels;
}
