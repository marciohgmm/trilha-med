import 'package:flutter/material.dart';

import '../../models/questao_model.dart';

/// Card de questão em modo prova — sem gabarito nem feedback parcial.
class RevalidaExamQuestionCard extends StatelessWidget {
  const RevalidaExamQuestionCard({
    super.key,
    required this.questao,
    required this.questionNumber,
    required this.selectedAlternativaId,
    required this.onSelected,
  });

  final QuestaoModel questao;
  final int questionNumber;
  final String? selectedAlternativaId;
  final ValueChanged<String> onSelected;

  static const _labels = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final alternativas = List<QuestaoAlternativa>.from(questao.alternativas);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questão $questionNumber',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              questao.enunciado,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: false,
              child: RadioGroup<String>(
                groupValue: selectedAlternativaId,
                onChanged: (value) {
                  if (value != null) onSelected(value);
                },
                child: Column(
                  children: alternativas.asMap().entries.map((entry) {
                    final index = entry.key;
                    final alt = entry.value;
                    final label =
                        index < _labels.length ? _labels[index] : '${index + 1}';
                    final isSelected = selectedAlternativaId == alt.id;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelected(alt.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.08)
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RadioListTile<String>(
                            value: alt.id,
                            title: Text(
                              '$label) ${alt.texto}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            activeColor: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (selectedAlternativaId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.bookmark, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Alternativa marcada',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid de navegação rápida entre questões.
class RevalidaQuestionNavigatorSheet extends StatelessWidget {
  const RevalidaQuestionNavigatorSheet({
    super.key,
    required this.total,
    required this.currentIndex,
    required this.isAnswered,
    required this.onSelect,
  });

  final int total;
  final int currentIndex;
  final bool Function(int index) isAnswered;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ir para questão',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: total,
              itemBuilder: (context, index) {
                final answered = isAnswered(index);
                final current = index == currentIndex;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(index);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: current
                          ? const Color(0xFF1E3A8A)
                          : answered
                              ? const Color(0xFF059669).withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: current
                            ? const Color(0xFF1E3A8A)
                            : answered
                                ? const Color(0xFF059669)
                                : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: current ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String formatRevalidaDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
