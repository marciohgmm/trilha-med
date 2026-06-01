import 'package:flutter/material.dart';

import '../../data/osce_default_evaluation_rubric.dart';
import '../../models/osce_evaluation_models.dart';
import '../../services/osce/osce_evaluation_scoring.dart';
import '../../services/osce/osce_evaluation_service.dart';
import '../../widgets/osce/evaluation/evaluation_category_tile.dart';
import '../../widgets/osce/evaluation/evaluation_criterion_card.dart';
import '../../widgets/osce/evaluation/evaluation_score_header.dart';
import '../../widgets/osce/osce_scroll_physics.dart';
import 'osce_evaluation_history_page.dart';

class OsceEvaluationPage extends StatefulWidget {
  final String userId;
  final String roomId;
  final String? evaluationId;

  const OsceEvaluationPage({
    super.key,
    required this.userId,
    required this.roomId,
    this.evaluationId,
  });

  @override
  State<OsceEvaluationPage> createState() => _OsceEvaluationPageState();
}

class _OsceEvaluationPageState extends State<OsceEvaluationPage> {
  final _evalService = OsceEvaluationService();

  Map<String, List<String>> _checked = {};
  Map<String, String> _criterionRatings = {};
  OsceDiagnosisLevel _diagnosis = OsceDiagnosisLevel.wrong;
  bool _saving = false;
  bool _localDirty = false;

  void _syncFromRecord(OsceEvaluationRecord record) {
    if (_localDirty && !record.isFinalized) return;
    _checked = record.checkedItemIds.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    );
    _criterionRatings = Map<String, String>.from(record.criterionRatings);
    _diagnosis = record.diagnosisLevel;
  }

  OsceEvaluationScoreResult _scoreFor({
    required OsceEvaluationRubric rubric,
    required OsceEvaluationRecord record,
    required bool canEdit,
  }) {
    if (!canEdit) {
      return OsceEvaluationScoring.compute(
        rubric: rubric,
        criterionRatings: record.criterionRatings,
        checkedItemIds: record.checkedItemIds,
        diagnosisLevel: record.diagnosisLevel,
      );
    }
    return OsceEvaluationScoring.compute(
      rubric: rubric,
      criterionRatings: _criterionRatings,
      checkedItemIds: _checked,
      diagnosisLevel: _diagnosis,
    );
  }

  Map<String, String> _ratingsFor(OsceEvaluationRecord record, bool canEdit) =>
      canEdit ? _criterionRatings : record.criterionRatings;

  Map<String, List<String>> _checkedFor(OsceEvaluationRecord record, bool canEdit) =>
      canEdit ? _checked : record.checkedItemIds;

  OsceDiagnosisLevel _diagnosisFor(OsceEvaluationRecord record, bool canEdit) =>
      canEdit ? _diagnosis : record.diagnosisLevel;

  void _setCriterionLevel(
    String criterionId,
    OsceCriterionLevel level,
    OsceEvaluationRecord record,
  ) {
    if (!canEditFor(record)) return;
    setState(() {
      _localDirty = true;
      _criterionRatings[criterionId] = level.firestoreValue;
    });
    _persistDraft(record);
  }

  void _toggleItem(
    String categoryId,
    String itemId,
    OsceEvaluationRecord record,
  ) {
    if (!canEditFor(record)) return;
    setState(() {
      _localDirty = true;
      final list = List<String>.from(_checked[categoryId] ?? []);
      if (list.contains(itemId)) {
        list.remove(itemId);
      } else {
        list.add(itemId);
      }
      _checked[categoryId] = list;
    });
    _persistDraft(record);
  }

  void _setDiagnosis(OsceDiagnosisLevel level, OsceEvaluationRecord record) {
    if (!canEditFor(record)) return;
    setState(() {
      _localDirty = true;
      _diagnosis = level;
    });
    _persistDraft(record);
  }

  Future<void> _persistDraft(OsceEvaluationRecord record) async {
    if (record.isFinalized || !canEditFor(record)) return;
    try {
      await _evalService.updateDraft(
        evaluationId: record.id,
        criterionRatings: _criterionRatings,
        checkedItemIds: _checked,
        diagnosisLevel: _diagnosis,
        rubricSnapshot: record.rubricSnapshot,
      );
      if (mounted) setState(() => _localDirty = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar nota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool canEditFor(OsceEvaluationRecord record) =>
      record.evaluatorId == widget.userId && !record.isFinalized;

  Future<void> _finalize(OsceEvaluationRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar avaliação?'),
        content: Text(
          'A nota ${record.totalScore.toStringAsFixed(1)}/10 será salva no '
          'progresso de ${record.evaluatedName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _evalService.finalizeEvaluation(
        evaluationId: record.id,
        requesterId: widget.userId,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OsceEvaluationResultPage(
            evaluationId: record.id,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OsceEvaluationRecord?>(
      stream: widget.evaluationId != null
          ? _evalService.streamById(widget.evaluationId!)
          : _evalService.streamByRoom(widget.roomId),
      builder: (context, snap) {
        final record = snap.data;
        if (record == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final canEdit =
            !record.isFinalized && record.evaluatorId == widget.userId;

        if (canEdit) {
          if (!_localDirty || record.isFinalized) {
            _syncFromRecord(record);
          }
        }

        final rubric = OsceDefaultEvaluationRubric.resolve(
          record.rubricSnapshot,
        );
        final result = _scoreFor(
          rubric: rubric,
          record: record,
          canEdit: canEdit,
        );
        final displayTotal =
            canEdit ? result.totalScore : record.totalScore;
        final displayMax = record.maxScore;
        final displayPct = canEdit
            ? result.performancePercent
            : record.performancePercent;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          appBar: AppBar(
            title: const Text('Avaliação OSCE'),
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Histórico',
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OsceEvaluationHistoryPage(
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: OsceScrollPhysics.list,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16 + MediaQuery.paddingOf(context).left,
                        16,
                        16 + MediaQuery.paddingOf(context).right,
                        16,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          EvaluationScoreHeader(
                            totalScore: displayTotal,
                            maxScore: displayMax,
                            performancePercent: displayPct,
                            readOnly: !canEdit || record.isFinalized,
                          ),
                          const SizedBox(height: 16),
                          _InfoBanner(record: record, canEdit: canEdit),
                          const SizedBox(height: 16),
                          ..._buildCategories(
                            rubric: rubric,
                            result: result,
                            record: record,
                            canEdit: canEdit,
                            ratings: _ratingsFor(record, canEdit),
                            checked: _checkedFor(record, canEdit),
                            diagnosis: _diagnosisFor(record, canEdit),
                          ),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom: canEdit ? 96 : 32,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                Material(
                  elevation: 8,
                  color: const Color(0xFFF0F4F8),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton(
                      onPressed: _saving ? null : () => _finalize(record),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Finalizar avaliação',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  ),
                )
              else if (!record.isFinalized)
                Material(
                  color: const Color(0xFFF0F4F8),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Somente o avaliador pode marcar os itens. '
                        'Acompanhe a nota em tempo real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                )
              else
                Material(
                  elevation: 4,
                  color: const Color(0xFFF0F4F8),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.popUntil(context, (r) => r.isFirst);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Voltar ao início'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCategories({
    required OsceEvaluationRubric rubric,
    required OsceEvaluationScoreResult result,
    required OsceEvaluationRecord record,
    required bool canEdit,
    required Map<String, String> ratings,
    required Map<String, List<String>> checked,
    required OsceDiagnosisLevel diagnosis,
  }) {
    if (rubric.usesCriteriaMode) {
      return rubric.criteria.map((c) {
        final level = OsceCriterionLevel.fromValue(ratings[c.id]);
        final score = result.categoryScores[c.id] ?? 0;
        return EvaluationCriterionCard(
          criterion: c,
          selectedLevel: level,
          score: score,
          canEdit: canEdit,
          onLevelSelected: (l) => _setCriterionLevel(c.id, l, record),
        );
      }).toList();
    }

    final widgets = <Widget>[];
    final enabled = rubric.enabledCategoryIds;

    for (final catId in enabled) {
      final max = categoryMaxScore(catId, rubric);
      final score = result.categoryScores[catId] ?? 0;

      if (catId == OsceEvaluationCategoryId.diagnosis.key) {
        widgets.add(
          EvaluationDiagnosisSelector(
            level: diagnosis,
            score: score,
            maxScore: max,
            canEdit: canEdit,
            title: categoryLabel(catId, rubric),
            acceptedDiagnoses: rubric.acceptedDiagnoses,
            onChanged: (l) => _setDiagnosis(l, record),
          ),
        );
        continue;
      }

      if (catId == OsceEvaluationCategoryId.exams.key) {
        if (!rubric.enableExamsCategory) continue;
        widgets.add(
          EvaluationCategoryTile(
            categoryId: catId,
            label: categoryLabel(catId, rubric),
            score: score,
            maxScore: max,
            items: rubric.expectedExams,
            checkedIds: checked[catId]?.toSet() ?? {},
            canEdit: canEdit,
            onToggleItem: (id) => _toggleItem(catId, id, record),
          ),
        );
        continue;
      }

      final items = rubric.checklists[catId] ?? [];
      widgets.add(
        EvaluationCategoryTile(
          categoryId: catId,
          label: categoryLabel(catId, rubric),
          score: score,
          maxScore: max,
          items: items,
          checkedIds: checked[catId]?.toSet() ?? {},
          canEdit: canEdit,
          onToggleItem: (id) => _toggleItem(catId, id, record),
        ),
      );
    }

    for (final extra in rubric.extraCategories) {
      widgets.add(
        EvaluationCategoryTile(
          categoryId: extra.id,
          label: extra.label,
          score: result.categoryScores[extra.id] ?? 0,
          maxScore: extra.maxScore,
          items: extra.items,
          checkedIds: checked[extra.id]?.toSet() ?? {},
          canEdit: canEdit,
          onToggleItem: (id) => _toggleItem(extra.id, id, record),
        ),
      );
    }

    return widgets;
  }
}

class _InfoBanner extends StatelessWidget {
  final OsceEvaluationRecord record;
  final bool canEdit;

  const _InfoBanner({required this.record, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.caseTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 6),
          Text('${record.stationName} · ${record.specialty}'),
          Text('Médico: ${record.evaluatedName}'),
          Text('Avaliador: ${record.evaluatorName}'),
          if (record.durationInSeconds > 0)
            Text('Duração: ${_fmt(record.durationInSeconds)}'),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                record.rubricSnapshot.usesCriteriaMode
                    ? 'Toque em Adequado, Parcialmente adequado ou Inadequado '
                        'em cada critério. A nota (0–10) atualiza automaticamente.'
                    : 'Marque os itens realizados pelo médico. '
                        'A nota atualiza automaticamente.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488)),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Tela de resultado após finalizar.
class OsceEvaluationResultPage extends StatelessWidget {
  final String evaluationId;
  final String userId;

  const OsceEvaluationResultPage({
    super.key,
    required this.evaluationId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return OsceEvaluationPage(
      userId: userId,
      roomId: '',
      evaluationId: evaluationId,
    );
  }
}
