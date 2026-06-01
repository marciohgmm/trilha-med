import 'package:flutter/material.dart';

import '../../../models/osce_evaluation_models.dart';

/// Card de um critério na correção ao vivo (botões Adequado / Parcial / Inadequado).
class EvaluationCriterionCard extends StatelessWidget {
  final OsceEvaluationCriterion criterion;
  final OsceCriterionLevel? selectedLevel;
  final double score;
  final bool canEdit;
  final ValueChanged<OsceCriterionLevel> onLevelSelected;

  const EvaluationCriterionCard({
    super.key,
    required this.criterion,
    required this.selectedLevel,
    required this.score,
    required this.canEdit,
    required this.onLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterion.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      if (criterion.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          criterion.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    Text(
                      '/ ${criterion.scoreAdequate.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OsceCriterionLevel.values.map((level) {
                final isSelected = selectedLevel == level;
                final pts = criterion.pointsFor(level);
                return _LevelButton(
                  label: level.label,
                  points: pts,
                  selected: isSelected,
                  enabled: canEdit,
                  color: _colorForLevel(level),
                  onTap: () => onLevelSelected(level),
                );
              }).toList(),
            ),
            if (selectedLevel != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _explanationFor(selectedLevel!),
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _explanationFor(OsceCriterionLevel level) {
    switch (level) {
      case OsceCriterionLevel.adequate:
        return criterion.explainAdequate;
      case OsceCriterionLevel.partial:
        return criterion.explainPartial;
      case OsceCriterionLevel.inadequate:
        return criterion.explainInadequate;
    }
  }

  Color _colorForLevel(OsceCriterionLevel level) {
    switch (level) {
      case OsceCriterionLevel.adequate:
        return const Color(0xFF059669);
      case OsceCriterionLevel.partial:
        return const Color(0xFFD97706);
      case OsceCriterionLevel.inadequate:
        return const Color(0xFFDC2626);
    }
  }
}

class _LevelButton extends StatelessWidget {
  final String label;
  final double points;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _LevelButton({
    required this.label,
    required this.points,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: enabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                points.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: enabled ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
