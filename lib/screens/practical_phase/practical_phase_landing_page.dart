import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics_events.dart';
import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/practical_phase_module.dart';
import '../../services/practical_phase_module_service.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';
import '../../widgets/practical_phase/practical_phase_module_tile.dart';
import 'practical_phase_dashboard_page.dart';

/// Landing premium da Fase Prática (referência de organização, não cópia).
class PracticalPhaseLandingPage extends StatefulWidget {
  final String userId;

  const PracticalPhaseLandingPage({super.key, required this.userId});

  @override
  State<PracticalPhaseLandingPage> createState() =>
      _PracticalPhaseLandingPageState();
}

class _PracticalPhaseLandingPageState extends State<PracticalPhaseLandingPage>
    with AnalyticsFeatureTracker {
  final _moduleService = PracticalPhaseModuleService();

  @override
  void initState() {
    super.initState();
    trackFeatureOnce(
      AnalyticsEvents.practicalPhaseOpen,
      userId: widget.userId,
    );
    _moduleService.seedIfEmpty();
  }

  int _crossAxis(double w) {
    if (w >= 1100) return 3;
    if (w >= 700) return 2;
    return 1;
  }

  Future<void> _openModule(PracticalPhaseModule module) async {
    final link = module.linkUrl?.trim();
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticalPhaseDashboardPage(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      body: StreamBuilder<List<PracticalPhaseModule>>(
        stream: _moduleService.streamPublished(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final modules = snapshot.data ?? [];
          final grouped = _moduleService.groupBySection(modules);
          final sectionOrder = PracticalPhaseModule.sectionLabels.keys
              .where((k) => grouped.containsKey(k))
              .toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: PracticalPhaseColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroBackground(
                    onPrimaryCta: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PracticalPhaseDashboardPage(
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  modules.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (modules.isEmpty)
                SliverFillRemaining(
                  child: _emptyState(context),
                )
              else
                ...sectionOrder.map((key) {
                  final list = grouped[key]!;
                  return SliverToBoxAdapter(
                    child: _SectionBlock(
                      title: PracticalPhaseModule.sectionLabels[key]!,
                      modules: list,
                      crossAxisCount: _crossAxis,
                      onTapModule: _openModule,
                    ),
                  );
                }),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: PracticalPhaseInsets.page(context, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Conteúdo em preparação',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PracticalPhaseColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PracticalPhaseDashboardPage(userId: widget.userId),
                  ),
                );
              },
              child: const Text('Ver modelos OSCE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  final VoidCallback onPrimaryCta;

  const _HeroBackground({required this.onPrimaryCta});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0D9488),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24 + MediaQuery.paddingOf(context).left,
            48,
            24 + MediaQuery.paddingOf(context).right,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FASE PRÁTICA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Treine como na prova.\nDomine a prática clínica.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Simulados, OSCE, casos clínicos e revisão — tudo organizado para a Revalida.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onPrimaryCta,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Acessar biblioteca de modelos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final List<PracticalPhaseModule> modules;
  final int Function(double) crossAxisCount;
  final void Function(PracticalPhaseModule) onTapModule;

  const _SectionBlock({
    required this.title,
    required this.modules,
    required this.crossAxisCount,
    required this.onTapModule,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: PracticalPhaseInsets.section(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: PracticalPhaseColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${modules.length} recurso(s) disponível(is)',
            style: const TextStyle(color: PracticalPhaseColors.muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cross = crossAxisCount(constraints.maxWidth);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: cross == 1 ? 1.35 : 0.92,
                ),
                itemCount: modules.length,
                itemBuilder: (context, i) {
                  return PracticalPhaseModuleTile(
                    module: modules[i],
                    onTap: () => onTapModule(modules[i]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
