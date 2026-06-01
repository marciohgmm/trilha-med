import 'package:flutter/material.dart';

import '../../application/platform/master_admin_diagnostics_models.dart';
import 'master_admin_diagnostics_panel.dart';

/// Diálogo fullscreen com o relatório técnico (somente Painel Mestre).
Future<void> showMasterAdminDiagnosticsDialog(
  BuildContext context, {
  required MasterAdminDiagnosticReport report,
  Object? triggerError,
  Future<void> Function()? onRefresh,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diagnóstico técnico'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: MasterAdminDiagnosticsPanel(
          report: report,
          triggerError: triggerError,
          onRefresh: onRefresh,
        ),
      ),
    ),
  );
}
