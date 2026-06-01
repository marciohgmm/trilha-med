import '../../models/questao_model.dart';
import 'revalida_official_config.dart';

/// Calcula desempenho detalhado a partir das respostas da prova.
class RevalidaPerformanceCalculator {
  RevalidaPerformanceResult calculate({
    required List<QuestaoModel> questoes,
    required Map<String, String> selectedAlternativaByQuestaoId,
    required int durationSeconds,
  }) {
    var correct = 0;
    var wrong = 0;
    var unanswered = 0;

    final subjectMap = <String, _MutableBreakdown>{};
    final subtopicMap = <String, _MutableSubtopicBreakdown>{};

    for (final q in questoes) {
      final selected = selectedAlternativaByQuestaoId[q.id];
      final subjectKey =
          q.materia.trim().isEmpty ? '(sem matéria)' : q.materia;
      final subtopicKey =
          q.subtema.trim().isEmpty ? '(sem subtema)' : q.subtema;

      subjectMap.putIfAbsent(subjectKey, _MutableBreakdown.new);
      subtopicMap.putIfAbsent(
        '$subjectKey|$subtopicKey',
        () => _MutableSubtopicBreakdown(subjectKey, subtopicKey),
      );

      final subj = subjectMap[subjectKey]!;
      final subt = subtopicMap['$subjectKey|$subtopicKey']!;
      subj.total++;
      subt.total++;

      if (selected == null || selected.isEmpty) {
        unanswered++;
        subj.unanswered++;
        subt.unanswered++;
        continue;
      }

      if (selected == q.corretaId) {
        correct++;
        subj.correct++;
        subt.correct++;
      } else {
        wrong++;
        subj.wrong++;
        subt.wrong++;
      }
    }

    final total = questoes.length;
    final scorePercent = total > 0
        ? double.parse(((correct / total) * 100).toStringAsFixed(1))
        : 0.0;

    final subjectBreakdown = subjectMap.entries
        .map(
          (e) => RevalidaSubjectBreakdown(
            subject: e.key,
            total: e.value.total,
            correct: e.value.correct,
            wrong: e.value.wrong,
            unanswered: e.value.unanswered,
          ),
        )
        .toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));

    final subtopicBreakdown = subtopicMap.values
        .map(
          (v) => RevalidaSubtopicBreakdown(
            subject: v.subject,
            subtopic: v.subtopic,
            total: v.total,
            correct: v.correct,
            wrong: v.wrong,
            unanswered: v.unanswered,
          ),
        )
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final weaknessCandidates = subtopicBreakdown
        .where((s) => s.wrong > 0 || s.unanswered > 0)
        .toList()
      ..sort((a, b) {
        final err = b.errorRatePercent.compareTo(a.errorRatePercent);
        if (err != 0) return err;
        return b.wrong.compareTo(a.wrong);
      });

    final strengthCandidates = subtopicBreakdown
        .where((s) => s.correct > 0)
        .toList()
      ..sort((a, b) {
        final acc = b.accuracyPercent.compareTo(a.accuracyPercent);
        if (acc != 0) return acc;
        return b.correct.compareTo(a.correct);
      });

    return RevalidaPerformanceResult(
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      unanswered: unanswered,
      scorePercent: scorePercent,
      durationSeconds: durationSeconds,
      subjectBreakdown: subjectBreakdown,
      subtopicBreakdown: subtopicBreakdown,
      topWeaknesses: _toRanks(weaknessCandidates, true),
      topStrengths: _toRanks(strengthCandidates, false),
    );
  }

  List<RevalidaTopicRank> _toRanks(
    List<RevalidaSubtopicBreakdown> list,
    bool weakness,
  ) {
    return list.take(5).map((s) {
      return RevalidaTopicRank(
        label: '${s.subject} — ${s.subtopic}',
        subject: s.subject,
        subtopic: s.subtopic,
        total: s.total,
        correct: s.correct,
        wrong: s.wrong,
        ratePercent: weakness ? s.errorRatePercent : s.accuracyPercent,
      );
    }).toList();
  }
}

class _MutableBreakdown {
  int total = 0;
  int correct = 0;
  int wrong = 0;
  int unanswered = 0;
}

class _MutableSubtopicBreakdown {
  _MutableSubtopicBreakdown(this.subject, this.subtopic);

  final String subject;
  final String subtopic;
  int total = 0;
  int correct = 0;
  int wrong = 0;
  int unanswered = 0;
}

/// Distribui [total] questões de forma equilibrada entre matérias.
Map<String, int> computeBalancedMateriaQuotas({
  required List<String> materias,
  required int total,
}) {
  if (materias.isEmpty) return {};
  final n = materias.length;
  final base = total ~/ n;
  var remainder = total % n;
  final quotas = <String, int>{};
  for (final m in materias) {
    var q = base;
    if (remainder > 0) {
      q++;
      remainder--;
    }
    quotas[m] = q;
  }
  return quotas;
}

/// Seleciona questões equilibradas por matéria a partir de pools.
List<QuestaoModel> selectBalancedQuestions({
  required Map<String, List<QuestaoModel>> poolByMateria,
  required int total,
}) {
  final materias = poolByMateria.keys.toList()..sort();
  final quotas = computeBalancedMateriaQuotas(materias: materias, total: total);
  final selected = <QuestaoModel>[];
  final usedIds = <String>{};

  for (final materia in materias) {
    final needed = quotas[materia] ?? 0;
    if (needed <= 0) continue;
    final pool = poolByMateria[materia] ?? [];
    var picked = 0;
    for (final q in pool) {
      if (picked >= needed) break;
      if (usedIds.contains(q.id)) continue;
      usedIds.add(q.id);
      selected.add(q);
      picked++;
    }
  }

  if (selected.length < total) {
    final overflow = <QuestaoModel>[];
    for (final list in poolByMateria.values) {
      for (final q in list) {
        if (!usedIds.contains(q.id)) overflow.add(q);
      }
    }
    for (final q in overflow) {
      if (selected.length >= total) break;
      usedIds.add(q.id);
      selected.add(q);
    }
  }

  return selected.take(total).toList();
}
