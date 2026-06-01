import 'package:flutter/material.dart';

import '../../domain/revalida_official/revalida_official_config.dart';
import '../../models/questao_model.dart';
import '../../models/revalida_simulation_model.dart';
import '../../services/revalida_official/revalida_weakness_study_service.dart';
import '../questoes_page.dart';
import '../subtemas_page.dart';

/// Plano de correção automático a partir das fraquezas.
class RevalidaWeaknessStudyPage extends StatefulWidget {
  const RevalidaWeaknessStudyPage({
    super.key,
    required this.userId,
    required this.record,
    required this.questoes,
    required this.performance,
  });

  final String userId;
  final RevalidaSimulationRecord record;
  final List<QuestaoModel> questoes;
  final RevalidaPerformanceResult performance;

  @override
  State<RevalidaWeaknessStudyPage> createState() =>
      _RevalidaWeaknessStudyPageState();
}

class _RevalidaWeaknessStudyPageState extends State<RevalidaWeaknessStudyPage> {
  final _service = RevalidaWeaknessStudyService();
  RevalidaWeaknessStudyPlan? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final weak = widget.performance.subtopicBreakdown
          .where((s) => s.wrong > 0 || s.unanswered > 0)
          .toList();
      final plan = await _service.buildPlan(
        weakSubtopics: weak,
        examQuestions: widget.questoes,
        selecoes: widget.record.respostas,
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Estudar fraquezas'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erro: $_error'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Plano gerado com base nos seus erros nesta prova.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Subtemas prioritários',
                      icon: Icons.priority_high,
                      child: Column(
                        children: _plan!.subtopicLabels
                            .map(
                              (l) => ListTile(
                                leading: const Icon(Icons.flag_outlined,
                                    color: Color(0xFFDC2626)),
                                title: Text(l),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    _Section(
                      title:
                          'Flashcards relacionados (${_plan!.flashcardIds.length})',
                      icon: Icons.style_outlined,
                      child: _plan!.flashcardIds.isEmpty
                          ? const Text('Nenhum flashcard encontrado.')
                          : Column(
                              children: _plan!.weakSubtopics.map((sub) {
                                return ListTile(
                                  title: Text('${sub.subject} — ${sub.subtopic}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SubtemasPage(
                                          userId: widget.userId,
                                          materia: sub.subject,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    _Section(
                      title:
                          'Questões relacionadas (${_plan!.questaoIds.length})',
                      icon: Icons.quiz_outlined,
                      child: _plan!.questaoIds.isEmpty
                          ? const Text('Nenhuma questão extra encontrada.')
                          : Column(
                              children: _plan!.weakSubtopics.map((sub) {
                                return ListTile(
                                  title: Text(
                                    'Praticar: ${sub.subject} — ${sub.subtopic}',
                                  ),
                                  subtitle: Text(
                                    'Taxa de erro: '
                                    '${sub.errorRatePercent.toStringAsFixed(0)}%',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => QuestoesPage(
                                          userId: widget.userId,
                                          materia: sub.subject,
                                          subtema: sub.subtopic,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
