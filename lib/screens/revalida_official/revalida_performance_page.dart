import 'package:flutter/material.dart';

import '../../domain/revalida_official/revalida_official_config.dart';
import '../../domain/revalida_official/revalida_performance_calculator.dart';
import '../../models/questao_model.dart';
import '../../models/revalida_simulation_model.dart';
import '../../widgets/revalida_official/revalida_exam_question_card.dart';
import 'revalida_evolution_dashboard_page.dart';
import 'revalida_weakness_study_page.dart';

/// Análise pós-simulado Revalida Oficial.
class RevalidaPerformancePage extends StatelessWidget {
  const RevalidaPerformancePage({
    super.key,
    required this.userId,
    required this.record,
    required this.questoes,
  });

  final String userId;
  final RevalidaSimulationRecord record;
  final List<QuestaoModel> questoes;

  RevalidaPerformanceResult get _performance {
    return RevalidaPerformanceCalculator().calculate(
      questoes: questoes,
      selectedAlternativaByQuestaoId: record.respostas,
      durationSeconds: record.durationSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final perf = _performance;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Resultado — Revalida Oficial'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScoreHeader(
              score: perf.scorePercent,
              correct: perf.correctAnswers,
              wrong: perf.wrongAnswers,
              unanswered: perf.unanswered,
              duration: record.durationSeconds,
            ),
            const SizedBox(height: 24),
            _SectionTitle('Desempenho por matéria'),
            ...perf.subjectBreakdown.map(
              (s) => _BreakdownBar(
                label: s.subject,
                percent: s.accuracyPercent,
                detail: '${s.correct}/${s.total} acertos',
                color: const Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle('Desempenho por subtema'),
            ...perf.subtopicBreakdown.take(15).map(
                  (s) => _BreakdownBar(
                    label: '${s.subject} — ${s.subtopic}',
                    percent: s.accuracyPercent,
                    detail:
                        '${s.correct}/${s.total} · ${s.wrong} erro(s)',
                    color: const Color(0xFF2563EB),
                  ),
                ),
            const SizedBox(height: 20),
            _RankSection(
              title: 'Top 5 pontos fracos',
              items: perf.topWeaknesses,
              isWeakness: true,
            ),
            const SizedBox(height: 16),
            _RankSection(
              title: 'Top 5 pontos fortes',
              items: perf.topStrengths,
              isWeakness: false,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RevalidaWeaknessStudyPage(
                      userId: userId,
                      record: record,
                      questoes: questoes,
                      performance: perf,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.school),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Estudar minhas fraquezas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RevalidaEvolutionDashboardPage(userId: userId),
                  ),
                );
              },
              icon: const Icon(Icons.insights),
              label: const Text('Ver evolução'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.duration,
  });

  final double score;
  final int correct;
  final int wrong;
  final int unanswered;
  final int duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${score.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const Text('de acerto (100 questões)'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat('Acertos', '$correct', const Color(0xFF059669)),
              _MiniStat('Erros', '$wrong', const Color(0xFFDC2626)),
              _MiniStat('Em branco', '$unanswered', Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tempo: ${formatRevalidaDuration(duration)} / '
            '${formatRevalidaDuration(RevalidaOfficialConfig.defaultDurationSeconds)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.label,
    required this.percent,
    required this.detail,
    required this.color,
  });

  final String label;
  final double percent;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${percent.toStringAsFixed(0)}% · $detail',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankSection extends StatelessWidget {
  const _RankSection({
    required this.title,
    required this.items,
    required this.isWeakness,
  });

  final String title;
  final List<RevalidaTopicRank> items;
  final bool isWeakness;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          Text(
            'Sem dados suficientes.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        ...items.asMap().entries.map((e) {
          final rank = e.key + 1;
          final item = e.value;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isWeakness
                  ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                  : const Color(0xFF059669).withValues(alpha: 0.15),
              child: Text('$rank', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(item.label, style: const TextStyle(fontSize: 14)),
            trailing: Text(
              '${item.ratePercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWeakness ? const Color(0xFFDC2626) : const Color(0xFF059669),
              ),
            ),
          );
        }),
      ],
    );
  }
}
