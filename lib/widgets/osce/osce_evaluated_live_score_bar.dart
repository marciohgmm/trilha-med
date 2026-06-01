import 'package:flutter/material.dart';

import '../../models/osce_evaluation_models.dart';
import '../../services/osce/osce_evaluation_service.dart';
import '../../widgets/osce/evaluation/evaluation_score_header.dart';

/// Faixa fixa com a nota ao vivo para o médico avaliado (stream Firestore).
class OsceEvaluatedLiveScoreBar extends StatelessWidget {
  final String? evaluationId;
  final VoidCallback? onOpenFullEvaluation;

  const OsceEvaluatedLiveScoreBar({
    super.key,
    required this.evaluationId,
    this.onOpenFullEvaluation,
  });

  @override
  Widget build(BuildContext context) {
    final id = evaluationId?.trim();
    if (id == null || id.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    final service = OsceEvaluationService();
    return StreamBuilder<OsceEvaluationRecord?>(
      stream: service.streamById(id),
      builder: (context, snap) {
        final record = snap.data;
        if (record == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        final safe = MediaQuery.paddingOf(context);
        return Material(
          color: const Color(0xFF0D9488).withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16 + safe.left,
              10,
              16 + safe.right,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.live_tv, color: Color(0xFF0D9488), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sua nota está sendo registrada em tempo real',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    if (onOpenFullEvaluation != null)
                      TextButton(
                        onPressed: onOpenFullEvaluation,
                        child: const Text('Ver detalhes'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                EvaluationScoreHeader(
                  totalScore: record.totalScore,
                  maxScore: record.maxScore,
                  performancePercent: record.performancePercent,
                  readOnly: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
