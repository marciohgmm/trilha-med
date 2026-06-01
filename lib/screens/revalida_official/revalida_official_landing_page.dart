import 'package:flutter/material.dart';

import '../../core/feature_flags/feature_modules.dart';
import '../../domain/revalida_official/revalida_official_config.dart';
import '../../domain/revalida_official/revalida_exceptions.dart';
import '../../services/revalida_official/revalida_official_service.dart';
import '../../widgets/feature_flags/feature_gate.dart';
import 'revalida_evolution_dashboard_page.dart';
import 'revalida_official_play_page.dart';

/// Hub do Simulado Revalida Oficial.
class RevalidaOfficialLandingPage extends StatefulWidget {
  const RevalidaOfficialLandingPage({super.key, required this.userId});

  final String userId;

  @override
  State<RevalidaOfficialLandingPage> createState() =>
      _RevalidaOfficialLandingPageState();
}

class _RevalidaOfficialLandingPageState
    extends State<RevalidaOfficialLandingPage> {
  final _service = RevalidaOfficialService();
  bool _starting = false;

  Future<void> _iniciarProva() async {
    setState(() => _starting = true);
    final navigator = Navigator.of(context);

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
              Text('Montando prova oficial...\n100 questões equilibradas.'),
            ],
          ),
        ),
      ),
    );

    try {
      await RevalidaOfficialSessionStore.instance.clear();
      final questoes = await _service.montarProvaOficial();
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => RevalidaOfficialPlayPage(
            userId: widget.userId,
            questoes: questoes,
          ),
        ),
      );
    } on RevalidaInsufficientQuestionsException catch (e) {
      if (!mounted) return;
      navigator.pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Banco insuficiente'),
          content: Text(
            'São necessárias ${e.required} questões, mas encontramos '
            'apenas ${e.available}. Adicione mais questões ao banco.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E3A8A);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Revalida Oficial'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Evolução',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RevalidaEvolutionDashboardPage(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.school, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Simulado Revalida Oficial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '100 questões · 4 horas · distribuição equilibrada · '
                    'modo prova sem gabarito',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoTile(
              icon: Icons.quiz_outlined,
              title: '${RevalidaOfficialConfig.questionCount} questões',
              subtitle: 'Mistura automática e equilibrada por matéria',
            ),
            _InfoTile(
              icon: Icons.timer_outlined,
              title: '4 horas',
              subtitle: 'Cronômetro regressivo no formato oficial',
            ),
            _InfoTile(
              icon: Icons.visibility_off_outlined,
              title: 'Modo prova',
              subtitle: 'Sem gabarito ou desempenho parcial durante a prova',
            ),
            _InfoTile(
              icon: Icons.fact_check_outlined,
              title: 'Revisão completa',
              subtitle: 'Revise todas as questões antes de entregar',
            ),
            _InfoTile(
              icon: Icons.analytics_outlined,
              title: 'Análise detalhada',
              subtitle: 'Desempenho por matéria, subtema e plano de correção',
            ),
            const SizedBox(height: 28),
            FeatureGate(
              moduleId: FeatureModules.revalidaOfficialSimulator,
              onEnabled: _iniciarProva,
              childBuilder: (onPressed) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _starting ? null : onPressed,
                  icon: _starting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'INICIAR PROVA OFICIAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1E3A8A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
