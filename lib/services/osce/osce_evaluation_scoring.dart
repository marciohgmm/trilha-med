import '../../data/osce_default_evaluation_rubric.dart';
import '../../models/osce_evaluation_models.dart';

/// Resultado do cálculo automático da avaliação.
class OsceEvaluationScoreResult {
  final Map<String, double> categoryScores;
  final double totalScore;
  final double maxScore;
  final int correctCount;
  final int totalChecklistItems;
  final double performancePercent;

  const OsceEvaluationScoreResult({
    required this.categoryScores,
    required this.totalScore,
    required this.maxScore,
    required this.correctCount,
    required this.totalChecklistItems,
    required this.performancePercent,
  });
}

/// Lógica pura de pontuação OSCE.
class OsceEvaluationScoring {
  OsceEvaluationScoring._();

  static OsceEvaluationScoreResult compute({
    required OsceEvaluationRubric rubric,
    Map<String, String> criterionRatings = const {},
    Map<String, List<String>> checkedItemIds = const {},
    OsceDiagnosisLevel diagnosisLevel = OsceDiagnosisLevel.wrong,
  }) {
    if (rubric.usesCriteriaMode) {
      return _computeCriteria(rubric, criterionRatings);
    }
    return _computeLegacy(
      rubric: rubric,
      checkedItemIds: checkedItemIds,
      diagnosisLevel: diagnosisLevel,
    );
  }

  static OsceEvaluationScoreResult _computeCriteria(
    OsceEvaluationRubric rubric,
    Map<String, String> criterionRatings,
  ) {
    final scores = <String, double>{};
    var total = 0.0;
    var rated = 0;

    for (final c in rubric.criteria) {
      final level = OsceCriterionLevel.fromValue(criterionRatings[c.id]);
      final pts = c.pointsFor(level);
      scores[c.id] = pts;
      total += pts;
      if (level != null) rated++;
    }

    const maxScore = OsceDefaultEvaluationRubric.maxTotal;
    final percent = maxScore > 0
        ? ((total / maxScore) * 100).clamp(0.0, 100.0)
        : 0.0;

    return OsceEvaluationScoreResult(
      categoryScores: scores,
      totalScore: double.parse(total.toStringAsFixed(2)),
      maxScore: maxScore,
      correctCount: rated,
      totalChecklistItems: rubric.criteria.length,
      performancePercent: double.parse(percent.toStringAsFixed(1)),
    );
  }

  static double proportionalScore(int checked, int total, double maxPoints) {
    if (total <= 0) return 0;
    if (checked <= 0) return 0;
    final ratio = (checked / total).clamp(0.0, 1.0);
    if (ratio <= 0.25) return maxPoints * 0.25;
    if (ratio <= 0.50) return maxPoints * 0.50;
    if (ratio <= 0.75) return maxPoints * 0.75;
    return maxPoints;
  }

  static double diagnosisScore(
    OsceDiagnosisLevel level,
    double maxPoints,
  ) {
    switch (level) {
      case OsceDiagnosisLevel.wrong:
        return 0;
      case OsceDiagnosisLevel.partialLow:
        return maxPoints * 0.4;
      case OsceDiagnosisLevel.partialHigh:
        return maxPoints * 0.6;
      case OsceDiagnosisLevel.correct:
        return maxPoints;
    }
  }

  static double examsScore(int correctExams, double maxPoints) {
    if (correctExams <= 0) return 0;
    if (correctExams == 1) return maxPoints * (0.2 / 0.7);
    if (correctExams == 2) return maxPoints * (0.4 / 0.7);
    return maxPoints;
  }

  static OsceEvaluationScoreResult _computeLegacy({
    required OsceEvaluationRubric rubric,
    required Map<String, List<String>> checkedItemIds,
    required OsceDiagnosisLevel diagnosisLevel,
  }) {
    final weights = rubric.weights.isNotEmpty
        ? rubric.weights
        : OsceDefaultEvaluationRubric.defaultWeights;

    final enabled = rubric.enabledCategoryIds.isNotEmpty
        ? rubric.enabledCategoryIds
        : OsceDefaultEvaluationRubric.defaultEnabledCategories(
            enableExams: rubric.enableExamsCategory,
          );

    final scores = <String, double>{};
    var correct = 0;
    var totalItems = 0;

    for (final catId in enabled) {
      final maxPts = weights[catId] ??
          OsceDefaultEvaluationRubric.defaultWeights[catId] ??
          0;

      if (catId == OsceEvaluationCategoryId.diagnosis.key) {
        scores[catId] = diagnosisScore(diagnosisLevel, maxPts);
        continue;
      }

      if (catId == OsceEvaluationCategoryId.exams.key) {
        if (!rubric.enableExamsCategory) continue;
        final checked =
            checkedItemIds[catId]?.length ?? checkedItemIds['exams']?.length ?? 0;
        correct += checked;
        totalItems += rubric.expectedExams.length;
        scores[catId] = examsScore(checked, maxPts);
        continue;
      }

      final items = rubric.checklists[catId] ?? [];
      if (items.isEmpty) {
        scores[catId] = 0;
        continue;
      }
      final checked = checkedItemIds[catId] ?? [];
      final n = checked.length;
      correct += n;
      totalItems += items.length;
      scores[catId] = proportionalScore(n, items.length, maxPts);
    }

    for (final extra in rubric.extraCategories) {
      final items = extra.items;
      if (items.isEmpty) continue;
      final checked = checkedItemIds[extra.id] ?? [];
      correct += checked.length;
      totalItems += items.length;
      scores[extra.id] = proportionalScore(
        checked.length,
        items.length,
        extra.maxScore,
      );
    }

    final maxScore = enabled.fold<double>(
          0,
          (s, id) =>
              s +
              (weights[id] ??
                  OsceDefaultEvaluationRubric.defaultWeights[id] ??
                  0),
        ) +
        rubric.extraCategories.fold<double>(0, (s, e) => s + e.maxScore);

    final total = scores.values.fold<double>(0, (a, b) => a + b);
    final percent =
        maxScore > 0 ? ((total / maxScore) * 100).clamp(0, 100) : 0.0;

    return OsceEvaluationScoreResult(
      categoryScores: scores,
      totalScore: double.parse(total.toStringAsFixed(2)),
      maxScore: maxScore,
      correctCount: correct,
      totalChecklistItems: totalItems,
      performancePercent: double.parse(percent.toStringAsFixed(1)),
    );
  }
}
