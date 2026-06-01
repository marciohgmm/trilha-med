import 'package:flutter/material.dart';

import '../../models/questao_model.dart';
import '../../services/revalida_official/revalida_official_service.dart';
import '../../widgets/revalida_official/revalida_exam_question_card.dart';
import 'revalida_performance_page.dart';

/// Revisão completa antes da entrega da prova.
class RevalidaOfficialReviewPage extends StatelessWidget {
  const RevalidaOfficialReviewPage({
    super.key,
    required this.userId,
    required this.questoes,
    required this.selecoes,
    required this.startedAt,
    required this.durationSeconds,
  });

  final String userId;
  final List<QuestaoModel> questoes;
  final Map<String, String> selecoes;
  final DateTime startedAt;
  final int durationSeconds;

  int get _answered =>
      questoes.where((q) => selecoes[q.id]?.isNotEmpty == true).length;

  int get _unanswered => questoes.length - _answered;

  Future<void> _entregar(BuildContext context) async {
    if (_unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Questões não marcadas'),
          content: Text(
            'Você ainda não marcou $_unanswered questão(ões). '
            'Deseja entregar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar à revisão'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entregar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text(
          'Após entregar, o gabarito será calculado e o resultado '
          'será salvo. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Entregar prova'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculando resultado...'),
            ],
          ),
        ),
      ),
    );

    try {
      final service = RevalidaOfficialService();
      final record = await service.entregarProva(
        uid: userId,
        questoes: questoes,
        selecoes: selecoes,
        startedAt: startedAt,
        durationSeconds: durationSeconds,
      );
      await RevalidaOfficialSessionStore.instance.clear();
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RevalidaPerformancePage(
            userId: userId,
            record: record,
            questoes: questoes,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao entregar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Revisão final'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  '$_answered de ${questoes.length} questões marcadas',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_unanswered > 0)
                  Text(
                    '$_unanswered não marcada(s)',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Tempo utilizado: ${formatRevalidaDuration(durationSeconds)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: questoes.length,
              itemBuilder: (context, index) {
                final q = questoes[index];
                final marked = selecoes[q.id]?.isNotEmpty == true;
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: marked
                        ? const Color(0xFF059669).withValues(alpha: 0.15)
                        : const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: marked
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _entregar(context),
                  icon: const Icon(Icons.send),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'ENTREGAR PROVA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
