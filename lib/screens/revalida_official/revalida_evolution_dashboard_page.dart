import 'package:flutter/material.dart';

import '../../models/revalida_simulation_model.dart';
import '../../services/revalida_official/revalida_simulation_repository.dart';
import '../../widgets/revalida_official/revalida_exam_question_card.dart';

/// Histórico e evolução dos simulados Revalida Oficial.
class RevalidaEvolutionDashboardPage extends StatelessWidget {
  const RevalidaEvolutionDashboardPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final repo = RevalidaSimulationRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Evolução Revalida'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RevalidaSimulationRecord>>(
        stream: repo.watchForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum simulado oficial concluído ainda.\n'
                  'Faça sua primeira prova para ver a evolução.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final summary = repo.summarize(records);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Melhor nota',
                      value: '${summary.bestScore.toStringAsFixed(1)}%',
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Média geral',
                      value: '${summary.averageScore.toStringAsFixed(1)}%',
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Última nota',
                      value: '${summary.latestScore.toStringAsFixed(1)}%',
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Evolução',
                      value: records.length >= 2
                          ? '${summary.evolutionPercent >= 0 ? '+' : ''}'
                              '${summary.evolutionPercent.toStringAsFixed(1)}%'
                          : '—',
                      color: summary.evolutionPercent >= 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Últimos simulados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 10),
              ...records.map((r) {
                final date = r.finishedAt.toLocal();
                final dateStr =
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}/'
                    '${date.year}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      child: Text(
                        '${r.score.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    title: Text(
                      '${r.correctAnswers}/${r.totalQuestions} acertos',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$dateStr · ${formatRevalidaDuration(r.durationSeconds)}',
                    ),
                    trailing: Text(
                      '${r.wrongAnswers} err.',
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
