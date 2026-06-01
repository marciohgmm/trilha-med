import 'package:flutter/material.dart';

class EvaluationScoreHeader extends StatelessWidget {
  final double totalScore;
  final double maxScore;
  final double performancePercent;
  final bool readOnly;

  const EvaluationScoreHeader({
    super.key,
    required this.totalScore,
    required this.maxScore,
    required this.performancePercent,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxScore > 0 ? (totalScore / maxScore).clamp(0.0, 1.0) : 0.0;
    Color accent;
    if (pct >= 0.7) {
      accent = const Color(0xFF059669);
    } else if (pct >= 0.5) {
      accent = const Color(0xFFD97706);
    } else {
      accent = const Color(0xFFDC2626);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            readOnly ? 'Resultado da avaliação' : 'Nota em tempo real',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${totalScore.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${performancePercent.toStringAsFixed(0)}% de desempenho nos itens',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
