import 'package:flutter/material.dart';

import '../../application/platform/master_admin_diagnostics_models.dart';
import '../../application/platform/master_admin_diagnostics_service.dart';

/// Expõe o relatório de diagnóstico do Painel Mestre aos módulos filhos.
class MasterAdminDiagnosticsScope extends InheritedWidget {
  const MasterAdminDiagnosticsScope({
    super.key,
    required this.report,
    required this.onRefresh,
    required super.child,
  });

  final MasterAdminDiagnosticReport? report;
  final Future<void> Function() onRefresh;

  static MasterAdminDiagnosticsScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MasterAdminDiagnosticsScope>();
  }

  @override
  bool updateShouldNotify(MasterAdminDiagnosticsScope oldWidget) {
    return report != oldWidget.report;
  }
}

/// Exibe diagnóstico técnico quando [error] é permission-denied; senão erro genérico.
class MasterAdminModuleErrorView extends StatelessWidget {
  final Object? error;

  const MasterAdminModuleErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    if (!MasterAdminDiagnosticsService.isPermissionDenied(error)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erro: $error'),
        ),
      );
    }

    final scope = MasterAdminDiagnosticsScope.maybeOf(context);
    return MasterAdminDiagnosticsPanel(
      report: scope?.report,
      triggerError: error,
      onRefresh: scope?.onRefresh,
    );
  }
}

/// Painel técnico visível apenas dentro do Painel Mestre (já protegido por AdminGate).
class MasterAdminDiagnosticsPanel extends StatelessWidget {
  final MasterAdminDiagnosticReport? report;
  final Object? triggerError;
  final Future<void> Function()? onRefresh;

  const MasterAdminDiagnosticsPanel({
    super.key,
    this.report,
    this.triggerError,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r == null) {
      return _minimalError(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, r),
          if (triggerError != null) ...[
            const SizedBox(height: 12),
            _triggerCard(triggerError!),
          ],
          const SizedBox(height: 16),
          _identitySection(r.identity),
          const SizedBox(height: 16),
          _probesSection(r.probes),
          const SizedBox(height: 16),
          _environmentSection(r.environmentFindings, r),
        ],
      ),
    );
  }

  Widget _minimalError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
            const SizedBox(height: 12),
            Text(
              'FirebaseError: permission-denied',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              triggerError?.toString() ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, MasterAdminDiagnosticReport r) {
    return Card(
      color: const Color(0xFF7F1D1D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diagnóstico técnico — Painel Mestre',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: () async {
                      await onRefresh!();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Diagnóstico atualizado.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Executar diagnóstico novamente',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gerado em ${_fmt(r.generatedAt)} · projectId: ${r.firebaseProjectId}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _triggerCard(Object error) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Color(0xFFDC2626)),
        title: const Text('Erro que disparou o diagnóstico'),
        subtitle: Text(error.toString()),
        isThreeLine: true,
      ),
    );
  }

  Widget _identitySection(MasterAdminIdentitySnapshot id) {
    return _section(
      title: 'Usuário autenticado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Autenticado', id.isAuthenticated ? 'sim' : 'não'),
          _kv('UID', id.uid.isEmpty ? '—' : id.uid),
          _kv('E-mail', id.email.isEmpty ? '—' : id.email),
          _kv('E-mail verificado', id.emailVerified ? 'sim' : 'não'),
          _kv('Founder (cliente)', id.isFounder ? 'sim' : 'não'),
          _kv('users/{uid} existe', id.usersDocExists ? 'sim' : 'não'),
          _kv('users.isAdmin', id.usersIsAdmin ? 'true' : 'false'),
          _kv('admins/{uid} existe', id.adminsDocExists ? 'sim' : 'não'),
          _kv(
            'rbacRoles',
            id.rbacRoles.isEmpty ? '(vazio)' : id.rbacRoles.join(', '),
          ),
          _kv(
            'isAppAdmin() efetivo',
            id.isAppAdminEffective ? 'true' : 'false',
            highlight: !id.isAppAdminEffective,
          ),
        ],
      ),
    );
  }

  Widget _probesSection(List<MasterAdminProbeResult> probes) {
    return _section(
      title: 'Sondas Firestore',
      child: Column(
        children: probes.map(_probeTile).toList(),
      ),
    );
  }

  Widget _probeTile(MasterAdminProbeResult p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          p.success ? Icons.check_circle : Icons.cancel,
          color: p.success ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
        title: Text(p.collection),
        subtitle: Text('Operação: ${p.operation}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Status', p.success ? 'OK' : 'FALHOU'),
                if (p.errorCode != null) _kv('Código', p.errorCode!),
                if (p.errorMessage != null) _kv('Mensagem', p.errorMessage!),
                if (!p.success && p.probableCause.isNotEmpty)
                  _kv('Motivo provável', p.probableCause),
                if (!p.success && p.suggestion.isNotEmpty)
                  _kv('Sugestão', p.suggestion),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _environmentSection(
    List<MasterAdminEnvironmentFinding> findings,
    MasterAdminDiagnosticReport r,
  ) {
    final items = findings.isNotEmpty
        ? findings
        : [
            if (r.hasPermissionDeniedProbes)
              const MasterAdminEnvironmentFinding(
                title: 'Falha de permissão detectada',
                detail: 'Uma ou mais sondas retornaram permission-denied.',
                suggestion: 'Revise as sondas acima e o deploy das rules.',
              )
            else
              const MasterAdminEnvironmentFinding(
                title: 'Ambiente aparentemente OK',
                detail: 'Sondas básicas passaram; se um módulo falhar, '
                    'verifique query específica (ex.: users count).',
                suggestion: 'Consulte docs/MASTER_ADMIN_CRITICAL_AUDIT.md',
              ),
          ];

    return _section(
      title: 'Diagnóstico do Ambiente',
      child: Column(
        children: items
            .map(
              (f) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(f.title),
                  subtitle: Text('${f.detail}\n\n→ ${f.suggestion}'),
                  isThreeLine: true,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _kv(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: highlight ? const Color(0xFFDC2626) : Colors.black87,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }
}

/// Banner compacto no topo do shell quando há problemas detectados.
class MasterAdminDiagnosticsBanner extends StatelessWidget {
  final MasterAdminDiagnosticReport report;
  final VoidCallback onExpand;

  const MasterAdminDiagnosticsBanner({
    super.key,
    required this.report,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final failed = report.probes.where((p) => !p.success).length;
    return Material(
      color: const Color(0xFFFEF2F2),
      child: InkWell(
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFDC2626)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Firestore permission-denied — toque para diagnóstico '
                  '($failed sonda(s) falhou)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF991B1B)),
            ],
          ),
        ),
      ),
    );
  }
}
