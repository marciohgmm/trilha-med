import 'package:flutter/material.dart';
import 'dart:math';

import '../models/questao_model.dart';
import '../services/questao_service.dart';

class QuestaoCard extends StatefulWidget {
  final QuestaoModel questao;
  final String? userId;
  final bool showNextButton;
  final VoidCallback? onNext;

  const QuestaoCard({
    super.key,
    required this.questao,
    this.userId,
    this.showNextButton = false,
    this.onNext,
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

  void _submitAnswer() {
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma alternativa antes de responder.')),
      );
      return;
    }

    setState(() {
      _answered = true;
      // Explicação só aparece quando o usuário pedir.
      _showExplicacao = false;
    });

    final userId = widget.userId;
    if (userId != null && userId.isNotEmpty) {
      final acertou = _selectedId == widget.questao.corretaId;
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
    final controller = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar erro na questão'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Descreva o erro (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (motivo == null) return;

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
        const SnackBar(content: Text('Reporte enviado para o admin. Obrigado!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar reporte: $e'), backgroundColor: Colors.red),
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
            RadioGroup<String>(
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

                    // Seleção (antes de responder): deixa um verde bem claro.
                    if (!_answered && isSelected) {
                      backgroundColor = Colors.green.withValues(alpha: 0.08);
                      borderColor = Colors.green.withValues(alpha: 0.55);
                    }
                    if (_answered) {
                      if (isCorrect) borderColor = Colors.green;
                      if (isSelected && !isCorrect) borderColor = Colors.red;
                      if (isCorrect) backgroundColor = Colors.green.shade50;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.white,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RadioListTile<String>(
                        value: alternativa.id,
                        enabled: !_answered,
                        title: Text(
                          '$label) ${alternativa.texto}',
                          style: TextStyle(
                            color: _answered && isCorrect
                                ? Colors.green.shade900
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            const SizedBox(height: 10),
            if (!_answered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Responder'),
                ),
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
                      color: acertou ? Colors.green.shade700 : Colors.red.shade700,
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
                ...(() {
                  final alts = List<QuestaoAlternativa>.from(questao.alternativas)
                    ..sort((a, b) => a.id.compareTo(b.id));

                  return alts.map((alt) {
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
                                '${alt.id}) ',
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
                  });
                })(),
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
                      child: Text(_showExplicacao ? 'Ocultar explicação' : 'Mostrar explicação'),
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
