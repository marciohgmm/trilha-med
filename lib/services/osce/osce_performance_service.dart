import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/osce_default_evaluation_rubric.dart';
import '../../models/osce_evaluation_models.dart';
import '../../models/performance_models.dart';
import 'osce_evaluation_service.dart';

/// Desempenho calculado a partir de [osce_evaluations] finalizadas (notas reais).
class OscePerformanceService {
  OscePerformanceService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _evaluationsCol =>
      _db.collection(OsceEvaluationService.collection);

  /// Percentuais ao vivo com base nas estações OSCE já avaliadas.
  Stream<Map<String, SpecialtyPerformance>> streamPerformance(String userId) {
    return _evaluationsCol
        .where('evaluatedUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final records = snap.docs
          .map(OsceEvaluationRecord.fromDoc)
          .where((r) => r.isFinalized)
          .toList();
      return _aggregateFromEvaluations(records);
    });
  }

  static Map<String, SpecialtyPerformance> _aggregateFromEvaluations(
    List<OsceEvaluationRecord> records,
  ) {
    final bySpecialty = <String, List<OsceEvaluationRecord>>{};
    for (final r in records) {
      final key = r.specialtyKey;
      if (!SpecialtyPerformance.specialties.containsKey(key)) continue;
      bySpecialty.putIfAbsent(key, () => []).add(r);
    }

    final out = <String, SpecialtyPerformance>{};
    for (final key in SpecialtyPerformance.specialties.keys) {
      final list = bySpecialty[key] ?? const [];
      out[key] = _buildSpecialtyPerformance(key, list);
    }
    return out;
  }

  static SpecialtyPerformance _buildSpecialtyPerformance(
    String key,
    List<OsceEvaluationRecord> list,
  ) {
    final emptySkills = {
      for (final s in SpecialtyPerformance.skillKeys) s: 0,
    };

    if (list.isEmpty) {
      return SpecialtyPerformance(
        key: key,
        name: SpecialtyPerformance.specialties[key] ?? key,
        overallPercent: 0,
        skills: emptySkills,
        stationCount: 0,
      );
    }

    var sumOverall = 0.0;
    final skillSums = <String, int>{
      for (final s in SpecialtyPerformance.skillKeys) s: 0,
    };
    final skillCounts = <String, int>{
      for (final s in SpecialtyPerformance.skillKeys) s: 0,
    };

    for (final r in list) {
      final pct = r.maxScore > 0
          ? (r.totalScore / r.maxScore) * 100
          : r.performancePercent;
      sumOverall += pct;

      final rubric = OsceDefaultEvaluationRubric.resolve(r.rubricSnapshot);
      final mapped = mapCategoryScoresToSkillPercents(
        rubric: rubric,
        categoryScores: r.categoryScores,
      );
      for (final e in mapped.entries) {
        if (!SpecialtyPerformance.skillKeys.contains(e.key)) continue;
        skillSums[e.key] = (skillSums[e.key] ?? 0) + e.value;
        skillCounts[e.key] = (skillCounts[e.key] ?? 0) + 1;
      }
    }

    final overall =
        (sumOverall / list.length).round().clamp(0, 100);

    final skills = <String, int>{};
    for (final s in SpecialtyPerformance.skillKeys) {
      final c = skillCounts[s] ?? 0;
      skills[s] = c > 0 ? (skillSums[s]! / c).round().clamp(0, 100) : 0;
    }

    return SpecialtyPerformance(
      key: key,
      name: SpecialtyPerformance.specialties[key] ?? key,
      overallPercent: overall,
      skills: skills,
      stationCount: list.length,
    );
  }

  /// Converte notas da avaliação OSCE → % por competência.
  static Map<String, int> mapCategoryScoresToSkillPercents({
    required OsceEvaluationRubric rubric,
    required Map<String, double> categoryScores,
  }) {
    if (rubric.usesCriteriaMode) {
      return _mapCriteriaToSkills(rubric.criteria, categoryScores);
    }

    final weights = OsceDefaultEvaluationRubric.defaultWeights;

    int pct(String cat, double max) {
      if (max <= 0) return 0;
      final score = categoryScores[cat] ?? 0;
      return ((score / max) * 100).round().clamp(0, 100);
    }

    return {
      'anamnese': pct('anamnesis', weights['anamnesis'] ?? 2.0),
      'exame_fisico': pct('physicalExam', weights['physicalExam'] ?? 2.0),
      'diagnostico': pct('diagnosis', weights['diagnosis'] ?? 2.5),
      'tratamento': pct('conduct', weights['conduct'] ?? 2.5),
      'laboratorio': pct('exams', weights['exams'] ?? 0.7),
      'apresentacao': pct('communication', weights['communication'] ?? 0.3),
    };
  }

  static Map<String, int> _mapCriteriaToSkills(
    List<OsceEvaluationCriterion> criteria,
    Map<String, double> scores,
  ) {
    int groupPct(List<String> ids) {
      var earned = 0.0;
      var max = 0.0;
      for (final id in ids) {
        OsceEvaluationCriterion? c;
        for (final x in criteria) {
          if (x.id == id) {
            c = x;
            break;
          }
        }
        if (c == null) continue;
        max += c.maxWeight;
        earned += scores[id] ?? 0;
      }
      if (max <= 0) return 0;
      return ((earned / max) * 100).round().clamp(0, 100);
    }

    return {
      'apresentacao': groupPct(['crit_apresentacao']),
      'anamnese': groupPct(['crit_anamnese', 'crit_manifestacoes']),
      'exame_fisico': groupPct(['crit_exame_fisico']),
      'laboratorio': groupPct(['crit_laboratorio', 'crit_imagem']),
      'diagnostico': groupPct(['crit_diagnostico']),
      'tratamento': groupPct(['crit_tratamento']),
    };
  }

  SpecialtyPerformance? getSpecialty(
    Map<String, SpecialtyPerformance> all,
    String key,
  ) =>
      all[key];

}
