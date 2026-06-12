import 'package:flutter/material.dart';
import 'dart:math';

import '../models/access_usage_stats.dart';
import '../models/questao_model.dart';
import '../core/access/app_access_feature.dart';
import '../widgets/access/free_limit_reached_view.dart';
import '../models/questao_exceptions.dart';
import '../services/questao_service.dart';
import '../utils/report_message_dialog.dart';

class QuestaoCard extends StatefulWidget {
  final QuestaoModel questao;
  final String? userId;
  final bool showNextButton;
  final VoidCallback? onNext;
  final void Function(String alternativaId, bool acertou)? onAnswered;
  final Future<ConsumeResult> Function(String questionId)? onBeforeAnswer;

  const QuestaoCard({
    super.key,
    required this.questao,
    this.userId,
    this.showNextButton = false,
    this.onNext,
    this.onAnswered,
    this.onBeforeAnswer,
  });

  @override
  State<QuestaoCard> createState() => _QuestaoCardState();
}

class _QuestaoCardState extends State<QuestaoCard> {
  String? _selectedId;
  bool _answered = false;
  bool _showExplicacao = false;
  bool _reportando = false;
  late final List<QuestaoAlternativa> _alternativasEmbaralhadas;

  static const List<String> _labels = ['A', 'B', 'C', 'D', 'E'];

  Future<void> _submitAnswer() async {
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione uma alternativa antes de responder.')),
      );
      return;
    }

    final onBefore = widget.onBeforeAnswer;
    if (onBefore != null) {
      final access = await onBefore(widget.questao.id);
      if (!mounted) return;
      if (!access.allowed) {
        await showContentAccessBlockedFeedback(
          context,
          feature: AppAccessFeature.questions,
          result: access,
        );
        return;
      }
    }

    setState(() {
      _answered = true;
      // Explicação só aparece quando o usuário pedir.
      _showExplicacao = false;
    });

    final acertou = _selectedId == widget.questao.corretaId;
    widget.onAnswered?.call(_selectedId!, acertou);

    final userId = widget.userId;
    if (userId != null && userId.isNotEmpty) {
      // Fire-and-forget: não bloqueia UI.
      QuestaoService().registrarResposta(
        userId: userId,
        questao: widget.questao,
        alternativaSelecionadaId: _selectedId!,
        acertou: acertou,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Embaralha uma vez por card, para não mudar a ordem a cada rebuild.
    _alternativasEmbaralhadas = List<QuestaoAlternativa>.from(
      widget.questao.alternativas,
    )..shuffle(Random());
  }

  Future<void> _reportarErro() async {
    if (!mounted) return;

    final motivo = await showReportTextDialog(
      context: context,
      title: 'Reportar erro na questão',
      hintText: 'Descreva o erro encontrado',
      maxLines: 6,
      emptyMessage: 'Descreva o erro antes de enviar.',
    );

    if (motivo == null || motivo.isEmpty) return;

    setState(() {
      _reportando = true;
    });

    try {
      await QuestaoService().reportarErroQuestao(
        questao: widget.questao,
        userId: widget.userId,
        motivo: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reporte enviado para o admin. Obrigado!')),
      );
    } on QuestaoReportAlreadyExistsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você já reportou esta questão anteriormente.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao enviar reporte: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reportando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questao = widget.questao;
    final bool acertou = _selectedId == questao.corretaId;

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
              questao.enunciado,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: _answered,
              child: RadioGroup<String>(
              groupValue: _selectedId,
              onChanged: (value) {
                if (_answered) return;
                setState(() {
                  _selectedId = value;
                });
              },
              child: Column(
                children: _alternativasEmbaralhadas.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final alternativa = entry.value;
                    final bool isSelected = alternativa.id == _selectedId;
                    final bool isCorrect = alternativa.id == questao.corretaId;
                    final label = index < _labels.length
                        ? _labels[index]
                        : '${index + 1}';

                    Color borderColor = Colors.grey.shade300;
                    Color? backgroundColor;

                    if (!_answered && isSelected) {
                      backgroundColor = Colors.green.withValues(alpha: 0.08);
                      borderColor = Colors.green.withValues(alpha: 0.55);
                    }
                    if (_answered) {
                      if (isCorrect) borderColor = Colors.green;
                      if (isSelected && !isCorrect) borderColor = Colors.red;
                      if (isCorrect) backgroundColor = Colors.green.shade50;
                    }

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _answered
                            ? null
                            : () {
                                setState(() {
                                  _selectedId = alternativa.id;
                                });
                              },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: backgroundColor ?? Colors.white,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RadioListTile<String>(
                            value: alternativa.id,
                            title: Text(
                              '$label) ${alternativa.texto}',
                              style: TextStyle(
                                color: _answered && isCorrect
                                    ? Colors.green.shade900
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            ),
            const SizedBox(height: 14),
            if (!_answered) _ResponderButton(
              hasSelection: _selectedId != null,
              onPressed: _submitAnswer,
            ),
            if (_answered) ...[
              Row(
                children: [
                  Icon(
                    acertou ? Icons.check_circle : Icons.cancel,
                    color: acertou ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    acertou ? 'Resposta correta' : 'Resposta incorreta',
                    style: TextStyle(
                      color:
                          acertou ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_showExplicacao) ...[
                const Text(
                  'Explicações por alternativa:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ..._alternativasEmbaralhadas.asMap().entries.map((entry) {
                  final index = entry.key;
                  final alt = entry.value;
                  final label = index < _labels.length
                      ? _labels[index]
                      : '${index + 1}';
                  final isCorrect = alt.id == questao.corretaId;
                  final justificativa =
                      questao.justificativasPorAlternativa[alt.id] ??
                          questao.explicacoesErradas[alt.id] ??
                          '';

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green.withValues(alpha: 0.45)
                            : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$label) ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCorrect
                                    ? Colors.green.shade800
                                    : Colors.black87,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                alt.texto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isCorrect)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                          ],
                        ),
                        if (justificativa.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(justificativa),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Sem explicação cadastrada.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showExplicacao = !_showExplicacao;
                        });
                      },
                      child: Text(_showExplicacao
                          ? 'Ocultar explicação'
                          : 'Mostrar explicação'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _reportando ? null : _reportarErro,
                    icon: _reportando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.report_problem_outlined),
                    label: const Text('Reportar erro'),
                  ),
                ],
              ),
              if (widget.showNextButton) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Próxima questão'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Botão principal de confirmação da resposta — destaque visual e feedback ao selecionar.
class _ResponderButton extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onPressed;

  const _ResponderButton({
    required this.hasSelection,
    required this.onPressed,
  });

  static const _primary = Color(0xFF1E3A8A);
  static const _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: hasSelection ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: hasSelection
                ? const [_primary, _accent]
                : [
                    _primary.withValues(alpha: 0.72),
                    _accent.withValues(alpha: 0.72),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: hasSelection ? 0.38 : 0.18),
              blurRadius: hasSelection ? 14 : 8,
              offset: Offset(0, hasSelection ? 6 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasSelection
                      ? Icons.send_rounded
                      : Icons.touch_app_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  hasSelection ? 'Confirmar resposta' : 'Responder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
