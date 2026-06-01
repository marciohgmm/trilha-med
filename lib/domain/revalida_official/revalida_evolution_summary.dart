import '../../models/revalida_simulation_model.dart';

/// Resumo estatístico da evolução do aluno (sem Firestore).
RevalidaEvolutionSummary summarizeRevalidaEvolution(
  List<RevalidaSimulationRecord> records,
) {
  if (records.isEmpty) {
    return const RevalidaEvolutionSummary(
      totalSimulations: 0,
      bestScore: 0,
      averageScore: 0,
      latestScore: 0,
      evolutionPercent: 0,
    );
  }

  final scores = records.map((r) => r.score).toList();
  final best = scores.reduce((a, b) => a > b ? a : b);
  final avg = scores.reduce((a, b) => a + b) / scores.length;
  final latest = records.first.score;

  double evolution = 0;
  if (records.length >= 2) {
    final previous = records[1].score;
    if (previous > 0) {
      evolution = double.parse(
        (((latest - previous) / previous) * 100).toStringAsFixed(1),
      );
    } else if (latest > 0) {
      evolution = 100;
    }
  }

  return RevalidaEvolutionSummary(
    totalSimulations: records.length,
    bestScore: best,
    averageScore: double.parse(avg.toStringAsFixed(1)),
    latestScore: latest,
    evolutionPercent: evolution,
  );
}
