import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../core/audit/audit_log_entry.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class MasterAdminAuditPage extends StatelessWidget {
  const MasterAdminAuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Auditoria',
      subtitle: 'Registros imutáveis (`platform_audit_logs`)',
      body: StreamBuilder<List<AuditLogEntry>>(
        stream: PlatformRegistry.instance.repositories.auditLogs
            .watchRecent(limit: 100),
        builder: (context, snap) {
          if (snap.hasError) {
            return MasterAdminModuleErrorView(error: snap.error);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('Nenhum evento de auditoria registrado.'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              final dt = e.createdAt;
              final when =
                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              return ListTile(
                leading: Icon(
                  e.eventType.key.contains('denied')
                      ? Icons.block
                      : Icons.check_circle_outline,
                  color: e.eventType.key.contains('denied')
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
                title: Text(e.eventType.key),
                subtitle: Text(
                  'Ator: ${e.actorUserId}\n'
                  '${e.entityType ?? ''} ${e.entityId ?? ''}\n'
                  '$when',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
