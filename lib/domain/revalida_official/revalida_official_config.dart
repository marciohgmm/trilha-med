/// Configuração do Simulado Revalida Oficial.
abstract final class RevalidaOfficialConfig {
  static const questionCount = 100;

  /// Tempo oficial INEP: 4 horas (240 min).
  static const defaultDurationSeconds = 4 * 60 * 60;

  /// Modo de prova: sem feedback até entrega.
  static const examMode = true;

  /// Cache local de pools — TTL configurável.
  static const poolCacheTtl = Duration(minutes: 30);

  /// Multiplicador de fetch por matéria (quota × multiplier + buffer).
  static const fetchLimitMultiplier = 3;
  static const fetchLimitMinBuffer = 10;
}

/// Breakdown por matéria.
class RevalidaSubjectBreakdown {
  const RevalidaSubjectBreakdown({
    required this.subject,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final String subject;
  final int total;
  final int correct;
  final int wrong;
  final int unanswered;

  double get accuracyPercent =>
      total == 0 ? 0 : (correct / total) * 100;

  double get errorRatePercent =>
      total == 0 ? 0 : (wrong / total) * 100;

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'total': total,
        'correct': correct,
        'wrong': wrong,
        'unanswered': unanswered,
        'accuracyPercent': double.parse(accuracyPercent.toStringAsFixed(1)),
      };

  factory RevalidaSubjectBreakdown.fromJson(Map<String, dynamic> json) {
    return RevalidaSubjectBreakdown(
      subject: json['subject']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      unanswered: (json['unanswered'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Breakdown por subtema (matéria + subtema).
class RevalidaSubtopicBreakdown {
  const RevalidaSubtopicBreakdown({
    required this.subject,
    required this.subtopic,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final String subject;
  final String subtopic;
  final int total;
  final int correct;
  final int wrong;
  final int unanswered;

  String get key => '$subject|$subtopic';

  double get errorRatePercent =>
      total == 0 ? 0 : (wrong / total) * 100;

  double get accuracyPercent =>
      total == 0 ? 0 : (correct / total) * 100;

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'subtopic': subtopic,
        'total': total,
        'correct': correct,
        'wrong': wrong,
        'unanswered': unanswered,
        'errorRatePercent': double.parse(errorRatePercent.toStringAsFixed(1)),
      };

  factory RevalidaSubtopicBreakdown.fromJson(Map<String, dynamic> json) {
    return RevalidaSubtopicBreakdown(
      subject: json['subject']?.toString() ?? '',
      subtopic: json['subtopic']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      unanswered: (json['unanswered'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ranking de fraqueza/força.
class RevalidaTopicRank {
  const RevalidaTopicRank({
    required this.label,
    required this.subject,
    this.subtopic,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.ratePercent,
  });

  final String label;
  final String subject;
  final String? subtopic;
  final int total;
  final int correct;
  final int wrong;
  final double ratePercent;
}

/// Resultado calculado após entrega da prova.
class RevalidaPerformanceResult {
  const RevalidaPerformanceResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.unanswered,
    required this.scorePercent,
    required this.durationSeconds,
    required this.subjectBreakdown,
    required this.subtopicBreakdown,
    required this.topWeaknesses,
    required this.topStrengths,
  });

  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int unanswered;
  final double scorePercent;
  final int durationSeconds;
  final List<RevalidaSubjectBreakdown> subjectBreakdown;
  final List<RevalidaSubtopicBreakdown> subtopicBreakdown;
  final List<RevalidaTopicRank> topWeaknesses;
  final List<RevalidaTopicRank> topStrengths;
}
