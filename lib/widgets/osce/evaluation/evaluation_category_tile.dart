import 'package:flutter/material.dart';

import '../../../data/osce_default_evaluation_rubric.dart';
import '../../../models/osce_evaluation_models.dart';

class EvaluationCategoryTile extends StatelessWidget {
  final String categoryId;
  final String label;
  final double score;
  final double maxScore;
  final List<OsceChecklistItem> items;
  final Set<String> checkedIds;
  final bool canEdit;
  final ValueChanged<String> onToggleItem;
  final Widget? trailing;

  const EvaluationCategoryTile({
    super.key,
    required this.categoryId,
    required this.label,
    required this.score,
    required this.maxScore,
    required this.items,
    required this.checkedIds,
    required this.canEdit,
    required this.onToggleItem,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: categoryId == 'diagnosis' || items.length <= 4,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: score >= maxScore * 0.75
                    ? const Color(0xFF059669)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        subtitle: trailing,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Nenhum item configurado para esta categoria.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...items.map((item) {
              final checked = checkedIds.contains(item.id);
              return CheckboxListTile(
                value: checked,
                onChanged: canEdit
                    ? (_) => onToggleItem(item.id)
                    : null,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: checked ? null : null,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class EvaluationDiagnosisSelector extends StatelessWidget {
  final OsceDiagnosisLevel level;
  final double score;
  final double maxScore;
  final bool canEdit;
  final ValueChanged<OsceDiagnosisLevel> onChanged;
  final List<String> acceptedDiagnoses;
  final String title;

  const EvaluationDiagnosisSelector({
    super.key,
    required this.level,
    required this.score,
    required this.maxScore,
    required this.canEdit,
    required this.onChanged,
    this.acceptedDiagnoses = const [],
    this.title = 'Hipótese diagnóstica',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                Text(
                  '${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (acceptedDiagnoses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Diagnósticos aceitos: ${acceptedDiagnoses.join(' · ')}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Errado', OsceDiagnosisLevel.wrong),
                _chip('Parcial (1,0)', OsceDiagnosisLevel.partialLow),
                _chip('Parcial (1,5)', OsceDiagnosisLevel.partialHigh),
                _chip('Correto', OsceDiagnosisLevel.correct),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, OsceDiagnosisLevel value) {
    final isSelected = value == level;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: canEdit ? (_) => onChanged(value) : null,
      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF0D9488),
    );
  }
}

String categoryLabel(String id, [OsceEvaluationRubric? rubric]) {
  final custom = rubric?.categoryLabels[id]?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  for (final c in OsceEvaluationCategoryId.values) {
    if (c.key == id) return c.label;
  }
  return id;
}

double categoryMaxScore(String id, OsceEvaluationRubric rubric) {
  return rubric.weights[id] ??
      OsceDefaultEvaluationRubric.defaultWeights[id] ??
      0;
}
