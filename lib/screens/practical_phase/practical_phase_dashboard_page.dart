import 'package:flutter/material.dart';

import '../../models/practical_phase_model.dart';
import '../../services/practical_phase_service.dart';
import '../../widgets/practical_phase/practical_phase_constants.dart';
import '../../widgets/practical_phase/practical_phase_empty_state.dart';
import '../../widgets/practical_phase/practical_phase_filters_bar.dart';
import '../../widgets/practical_phase/practical_phase_model_card.dart';
import '../../widgets/practical_phase/practical_phase_skeleton_grid.dart';
import 'practical_phase_detail_page.dart';

/// Dashboard do aluno — modelos publicados e ativos.
class PracticalPhaseDashboardPage extends StatefulWidget {
  final String userId;

  const PracticalPhaseDashboardPage({super.key, required this.userId});

  @override
  State<PracticalPhaseDashboardPage> createState() =>
      _PracticalPhaseDashboardPageState();
}

class _PracticalPhaseDashboardPageState
    extends State<PracticalPhaseDashboardPage> {
  final _service = PracticalPhaseService();
  PracticalPhaseFilters _filters = const PracticalPhaseFilters();
  int _visibleCount = 12;
  int _crossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PracticalPhaseColors.background,
      appBar: AppBar(
        title: const Text('Fase Prática'),
        backgroundColor: PracticalPhaseColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<List<PracticalPhaseModel>>(
        stream: _service.streamPublished(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return PracticalPhaseEmptyState(
              title: 'Erro ao carregar',
              message: '${snapshot.error}',
              icon: Icons.error_outline,
              actionLabel: 'Voltar',
              onAction: () => Navigator.pop(context),
            );
          }

          final waiting =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;
          if (waiting) {
            return SingleChildScrollView(
              padding: PracticalPhaseInsets.page(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) => PracticalPhaseSkeletonGrid(
                      crossAxisCount: _crossAxisCount(c.maxWidth),
                    ),
                  ),
                ],
              ),
            );
          }

          final all = snapshot.data ?? [];
          final filtered = _service.applyFilters(
            all,
            _filters,
            adminView: false,
          );

          final categories = _service
              .distinctValues(all, (m) => m.category)
              .toList()
            ..sort();
          final specialties = _service
              .distinctValues(all, (m) => m.specialty)
              .toList()
            ..sort();
          final difficulties = _service
              .distinctValues(all, (m) => m.difficulty)
              .toList()
            ..sort();

          final page = filtered.take(_visibleCount).toList();
          final hasMore = filtered.length > _visibleCount;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _visibleCount = 12);
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: PracticalPhaseInsets.page(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  PracticalPhaseFiltersBar(
                    filters: _filters,
                    categories: categories,
                    specialties: specialties,
                    difficulties: difficulties,
                    onChanged: (f) => setState(() {
                      _filters = f;
                      _visibleCount = 12;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (filtered.isEmpty)
                    PracticalPhaseEmptyState(
                      title: 'Nenhum modelo disponível',
                      message: all.isEmpty
                          ? 'Ainda não há simulações publicadas. '
                              'Volte em breve ou fale com o administrador.'
                          : 'Nenhum resultado para os filtros selecionados.',
                      actionLabel: 'Limpar filtros',
                      onAction: all.isEmpty
                          ? () => Navigator.pop(context)
                          : () => setState(
                                () => _filters = const PracticalPhaseFilters(),
                              ),
                    )
                  else ...[
                    Text(
                      '${filtered.length} modelo(s)',
                      style: const TextStyle(
                        color: PracticalPhaseColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cross = _crossAxisCount(constraints.maxWidth);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: cross == 1 ? 0.75 : 0.72,
                          ),
                          itemCount: page.length,
                          itemBuilder: (context, index) {
                            final model = page[index];
                            return PracticalPhaseModelCard(
                              model: model,
                              onOpen: () => _openModel(context, model),
                            );
                          },
                        );
                      },
                    ),
                    if (hasMore)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _visibleCount += 12,
                            ),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Carregar mais'),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PracticalPhaseColors.primary,
                PracticalPhaseColors.primary.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Treino & simulações',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Modelos de estações, procedimentos e roteiros para a fase prática.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openModel(BuildContext context, PracticalPhaseModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticalPhaseDetailPage(
          modelId: model.id,
          userId: widget.userId,
        ),
      ),
    );
  }
}
