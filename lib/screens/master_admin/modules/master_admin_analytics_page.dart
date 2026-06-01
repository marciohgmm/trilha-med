import 'package:flutter/material.dart';

import '../../../application/analytics/analytics_dashboard_service.dart';
import '../../../application/platform/master_admin_diagnostics_service.dart';
import '../../../core/analytics/analytics_events.dart';
import '../../../domain/platform/models/analytics_dashboard_snapshot.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';
import '../../../widgets/master_admin/master_admin_stat_card.dart';

class MasterAdminAnalyticsPage extends StatefulWidget {
  const MasterAdminAnalyticsPage({super.key});

  @override
  State<MasterAdminAnalyticsPage> createState() =>
      _MasterAdminAnalyticsPageState();
}

class _MasterAdminAnalyticsPageState extends State<MasterAdminAnalyticsPage> {
  final _service = AnalyticsDashboardService();
  AnalyticsDashboardSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _service.loadSnapshot();
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  String _pct(double v) => '${v.toStringAsFixed(1)}%';

  String _featureLabel(String key) {
    return switch (key) {
      AnalyticsEvents.flashcardStudyStart => 'Flashcards',
      AnalyticsEvents.questionsStudyStart => 'Questões',
      AnalyticsEvents.simuladoStart => 'Simulados (início)',
      AnalyticsEvents.simuladoComplete => 'Simulados (fim)',
      AnalyticsEvents.osceLobbyOpen => 'OSCE lobby',
      AnalyticsEvents.osceStationStart => 'OSCE estação',
      AnalyticsEvents.practicalPhaseOpen => 'Fase prática',
      AnalyticsEvents.liveEventJoin => 'Live events',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Analytics',
      subtitle: 'Crescimento, conversão e retenção (últimos 30 dias)',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
        ),
      ],
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      if (MasterAdminDiagnosticsService.isPermissionDenied(_error)) {
        return MasterAdminModuleErrorView(error: _error);
      }
      return Center(child: Text('Erro ao carregar: $_error'));
    }

    final s = _snapshot ?? AnalyticsDashboardSnapshot.empty();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Atualizado em ${_formatTime(s.generatedAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Crescimento'),
        _statGrid([
          MasterAdminStatCard(
            title: 'Cadastros (7d)',
            value: '${s.signUpsLast7Days}',
            icon: Icons.person_add_outlined,
            subtitle: '30d: ${s.signUpsLast30Days}',
          ),
          MasterAdminStatCard(
            title: 'Logins (7d)',
            value: '${s.loginsLast7Days}',
            icon: Icons.login,
          ),
          MasterAdminStatCard(
            title: 'Sessões (7d)',
            value: '${s.sessionsLast7Days}',
            icon: Icons.play_circle_outline,
          ),
          MasterAdminStatCard(
            title: 'DAU hoje',
            value: '${s.dailyActiveUsersToday}',
            icon: Icons.today_outlined,
            subtitle: 'Ontem: ${s.dailyActiveUsersYesterday}',
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle('Retenção (cohort cadastros 30d)'),
        _statGrid([
          MasterAdminStatCard(
            title: 'Retenção D1',
            value: _pct(s.retentionD1),
            icon: Icons.calendar_today_outlined,
            accentColor: const Color(0xFF059669),
            subtitle: 'Cohort: ${s.cohortSizeForRetention} usuários',
          ),
          MasterAdminStatCard(
            title: 'Retenção D7',
            value: _pct(s.retentionD7),
            icon: Icons.date_range_outlined,
            accentColor: const Color(0xFF2563EB),
          ),
          MasterAdminStatCard(
            title: 'Retenção D30',
            value: _pct(s.retentionD30),
            icon: Icons.event_available_outlined,
            accentColor: const Color(0xFF7C3AED),
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle('Conversão comercial'),
        _statGrid([
          MasterAdminStatCard(
            title: 'Paywall views',
            value: '${s.paywallViewsLast30Days}',
            icon: Icons.lock_outline,
          ),
          MasterAdminStatCard(
            title: 'Checkouts iniciados',
            value: '${s.checkoutStartsLast30Days}',
            icon: Icons.shopping_cart_outlined,
          ),
          MasterAdminStatCard(
            title: 'Compras aprovadas',
            value: '${s.purchasesApprovedLast30Days}',
            icon: Icons.check_circle_outline,
            accentColor: const Color(0xFF059669),
          ),
          MasterAdminStatCard(
            title: 'Taxa checkout → compra',
            value: _pct(s.checkoutConversionRate),
            icon: Icons.trending_up,
            subtitle:
                'Canceladas: ${s.purchasesCancelledLast30Days} · Receita: R\$ ${s.revenueLast30Days.toStringAsFixed(2)}',
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle('Uso de produto (GA4)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Features, cupons e afiliados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Eventos de alta frequência (flashcards, questões, simulados, OSCE, etc.) '
                  'não são mais espelhados no Firestore para reduzir custo. '
                  'Consulte o Firebase Analytics / GA4 para uso de produto detalhado.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _mapCard('Features (legado vazio)', s.featureUsageLast30Days, _featureLabel),
        const SizedBox(height: 16),
        _mapCard('Cupons aplicados', s.couponUsageLast30Days, (k) => k),
        const SizedBox(height: 16),
        _mapCard('Conversões afiliados', s.affiliateConversionsLast30Days, (k) => k),
        const SizedBox(height: 16),
        _mapCard('Conversões vendedores', s.sellerConversionsLast30Days, (k) => k),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firebase Analytics (GA4)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Eventos também são enviados ao Firebase Analytics. '
                  'Use o console GA4 para funis avançados e exportação BigQuery.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }

  Widget _statGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossCount == 1 ? 2.2 : 1.35,
          children: cards,
        );
      },
    );
  }

  Widget _mapCard(
    String title,
    Map<String, int> data,
    String Function(String) labelFor,
  ) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text('Sem dados', style: TextStyle(color: Colors.grey.shade600))
            else
              ...entries.take(10).map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(labelFor(e.key))),
                          Text(
                            '${e.value}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
