import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/osce_default_evaluation_rubric.dart';
import '../../../models/osce_evaluation_models.dart';

/// Editor de critérios avaliativos (aba Avaliação do caso OSCE).
class OsceEvaluationRubricEditor extends StatefulWidget {
  final OsceEvaluationRubric rubric;
  final ValueChanged<OsceEvaluationRubric> onChanged;

  const OsceEvaluationRubricEditor({
    super.key,
    required this.rubric,
    required this.onChanged,
  });

  @override
  State<OsceEvaluationRubricEditor> createState() =>
      _OsceEvaluationRubricEditorState();
}

class _OsceEvaluationRubricEditorState extends State<OsceEvaluationRubricEditor> {
  List<OsceEvaluationCriterion> get _criteria {
    if (widget.rubric.criteria.isNotEmpty) {
      return List<OsceEvaluationCriterion>.from(widget.rubric.criteria);
    }
    return OsceDefaultEvaluationRubric.defaultCriteria();
  }

  double get _somaPesos =>
      OsceEvaluationRubric.sumCriteriaMaxWeight(_criteria);

  double get _faltaPara10 =>
      (OsceDefaultEvaluationRubric.maxTotal - _somaPesos)
          .clamp(0, OsceDefaultEvaluationRubric.maxTotal);

  bool get _excedeu10 => _somaPesos > OsceDefaultEvaluationRubric.maxTotal + 0.001;

  void _emit(List<OsceEvaluationCriterion> criteria) {
    widget.onChanged(
      OsceEvaluationRubric(
        evaluationMode: 'criteria',
        criteria: criteria,
      ),
    );
  }

  void _atualizar(int index, OsceEvaluationCriterion c) {
    final next = List<OsceEvaluationCriterion>.from(_criteria);
    next[index] = c;
    _emit(next);
  }

  void _remover(int index) {
    if (_criteria.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mantenha ao menos um critério.')),
      );
      return;
    }
    final next = List<OsceEvaluationCriterion>.from(_criteria)..removeAt(index);
    _emit(next);
  }

  void _adicionar() {
    if (_excedeu10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A soma dos pesos já atingiu 10 pontos. '
            'Reduza um critério antes de adicionar outro.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final id = 'crit_${DateTime.now().millisecondsSinceEpoch}';
    final restante = _faltaPara10;
    final peso = restante >= 0.5 ? 0.5 : restante;
    _emit([
      ..._criteria,
      OsceEvaluationCriterion(
        id: id,
        title: 'Novo critério',
        description: 'Descreva o que será avaliado.',
        scoreAdequate: peso > 0 ? peso : 0.25,
        scorePartial: peso > 0 ? peso / 2 : 0.125,
        scoreInadequate: 0,
      ),
    ]);
  }

  void _restaurarPadrao() {
    _emit(OsceDefaultEvaluationRubric.defaultCriteria());
  }

  bool _podeSalvarPeso(double novoPeso, int index) {
    final outros = _criteria.asMap().entries.where((e) => e.key != index);
    final somaOutros =
        outros.fold<double>(0, (s, e) => s + e.value.maxWeight);
    return somaOutros + novoPeso <= OsceDefaultEvaluationRubric.maxTotal + 0.001;
  }

  @override
  Widget build(BuildContext context) {
    final somaCor = _excedeu10
        ? const Color(0xFFDC2626)
        : _faltaPara10 < 0.05
            ? const Color(0xFF059669)
            : const Color(0xFF1E3A8A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: _excedeu10 ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _excedeu10
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFF93C5FD),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nota máxima da estação: 10,0 pontos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pontuação total dos critérios',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '${_somaPesos.toStringAsFixed(2)} / 10',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: somaCor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_excedeu10 && _faltaPara10 > 0.01)
                      Chip(
                        label: Text(
                          'Faltam ${_faltaPara10.toStringAsFixed(2)} pts',
                        ),
                        backgroundColor: const Color(0xFFFFF7ED),
                      ),
                    if (_excedeu10)
                      const Chip(
                        label: Text('Ultrapassou 10!'),
                        backgroundColor: Color(0xFFFEE2E2),
                        labelStyle: TextStyle(color: Color(0xFFDC2626)),
                      ),
                  ],
                ),
                if (_excedeu10)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Reduza os pesos (campo Adequado) até a soma ser no máximo 10.',
                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _restaurarPadrao,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restaurar critérios padrão'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._criteria.asMap().entries.map((e) {
          return _CriterionEditorCard(
            key: ValueKey(e.value.id),
            index: e.key,
            criterion: e.value,
            onChanged: (c) => _atualizar(e.key, c),
            onRemove: () => _remover(e.key),
            canSetWeight: _podeSalvarPeso,
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _adicionar,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar critério'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _CriterionEditorCard extends StatefulWidget {
  final int index;
  final OsceEvaluationCriterion criterion;
  final ValueChanged<OsceEvaluationCriterion> onChanged;
  final VoidCallback onRemove;
  final bool Function(double novoPeso, int index) canSetWeight;

  const _CriterionEditorCard({
    super.key,
    required this.index,
    required this.criterion,
    required this.onChanged,
    required this.onRemove,
    required this.canSetWeight,
  });

  @override
  State<_CriterionEditorCard> createState() => _CriterionEditorCardState();
}

class _CriterionEditorCardState extends State<_CriterionEditorCard> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _scoreA;
  late TextEditingController _scoreP;
  late TextEditingController _scoreI;
  late TextEditingController _expA;
  late TextEditingController _expP;
  late TextEditingController _expI;

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.criterion);
  }

  @override
  void didUpdateWidget(covariant _CriterionEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.criterion.id != widget.criterion.id) {
      _disposeControllers();
      _syncControllers(widget.criterion);
    }
  }

  void _syncControllers(OsceEvaluationCriterion c) {
    _title = TextEditingController(text: c.title);
    _desc = TextEditingController(text: c.description);
    _scoreA = TextEditingController(text: c.scoreAdequate.toString());
    _scoreP = TextEditingController(text: c.scorePartial.toString());
    _scoreI = TextEditingController(text: c.scoreInadequate.toString());
    _expA = TextEditingController(text: c.explainAdequate);
    _expP = TextEditingController(text: c.explainPartial);
    _expI = TextEditingController(text: c.explainInadequate);
  }

  void _disposeControllers() {
    _title.dispose();
    _desc.dispose();
    _scoreA.dispose();
    _scoreP.dispose();
    _scoreI.dispose();
    _expA.dispose();
    _expP.dispose();
    _expI.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      widget.criterion.copyWith(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        scoreAdequate: double.tryParse(_scoreA.text.replaceAll(',', '.')) ??
            widget.criterion.scoreAdequate,
        scorePartial: double.tryParse(_scoreP.text.replaceAll(',', '.')) ??
            widget.criterion.scorePartial,
        scoreInadequate: double.tryParse(_scoreI.text.replaceAll(',', '.')) ??
            widget.criterion.scoreInadequate,
        explainAdequate: _expA.text.trim(),
        explainPartial: _expP.text.trim(),
        explainInadequate: _expI.text.trim(),
      ),
    );
  }

  void _onScoreAdequateChanged(String v) {
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return;
    if (!widget.canSetWeight(n, widget.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A soma dos pesos não pode ultrapassar 10 pontos.'),
          backgroundColor: Colors.red,
        ),
      );
      _scoreA.text = widget.criterion.scoreAdequate.toString();
      return;
    }
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criterion;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Peso máx.: ${c.scoreAdequate.toStringAsFixed(2)} pts',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover critério',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título do critério (inclua o peso se desejar)',
                border: OutlineInputBorder(),
                hintText:
                    '(1) Apresenta-se e (2) cumprimenta o(a) paciente simulado(a).',
              ),
              onChanged: (_) => _notify(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'O que será avaliado',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _notify(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pontuação por nível',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scoreA,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Adequado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onScoreAdequateChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _scoreP,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Parcialmente adequado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _scoreI,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Inadequado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Explicação dos níveis',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _expA,
              decoration: const InputDecoration(
                labelText: 'Adequado',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _notify(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _expP,
              decoration: const InputDecoration(
                labelText: 'Parcialmente adequado',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _notify(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _expI,
              decoration: const InputDecoration(
                labelText: 'Inadequado',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _notify(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Valida rubrica antes de salvar caso no admin.
bool osceRubricIsValidForSave(OsceEvaluationRubric rubric) {
  if (!rubric.usesCriteriaMode) return true;
  final sum = OsceEvaluationRubric.sumCriteriaMaxWeight(rubric.criteria);
  return sum <= OsceDefaultEvaluationRubric.maxTotal + 0.001;
}
