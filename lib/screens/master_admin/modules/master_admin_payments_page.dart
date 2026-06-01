import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../domain/platform/enums/platform_enums.dart';
import '../../../domain/platform/models/payment.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

/// Histórico de pagamentos, reembolsos e receita (Painel Mestre).
class MasterAdminPaymentsPage extends StatelessWidget {
  const MasterAdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = PlatformRegistry.instance.repositories;

    return DefaultTabController(
      length: 4,
      child: MasterAdminModuleScaffold(
        title: 'Pagamentos',
        subtitle: 'Mercado Pago · `platform_payments`',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabBar(
              labelColor: Color(0xFF1E3A8A),
              tabs: [
                Tab(text: 'Todos'),
                Tab(text: 'Aprovados'),
                Tab(text: 'Pendentes'),
                Tab(text: 'Reembolsos'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PaymentList(stream: repos.payments.watchAll(limit: 150)),
                  _PaymentList(
                    stream: repos.payments.watchByStatus(
                      PaymentStatus.succeeded,
                      limit: 100,
                    ),
                  ),
                  _PaymentList(
                    stream: repos.payments.watchByStatus(
                      PaymentStatus.pending,
                      limit: 100,
                    ),
                  ),
                  _PaymentList(
                    stream: repos.payments.watchByStatus(
                      PaymentStatus.refunded,
                      limit: 100,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.stream});

  final Stream<List<Payment>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Payment>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return MasterAdminModuleErrorView(error: snap.error);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum pagamento registrado.'));
        }

        String brl(double v) =>
            'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

        return ListView.separated(
          padding: const EdgeInsets.only(top: 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = items[i];
            return ListTile(
              leading: Icon(_iconForStatus(p.status)),
              title: Text('${brl(p.amount)} — ${p.status.key}'),
              subtitle: Text(
                'Usuário: ${p.userId}\n'
                'Provedor: ${p.provider.key}'
                '${p.providerPaymentId != null ? '\nMP ID: ${p.providerPaymentId}' : ''}'
                '${p.subscriptionId != null ? '\nAssinatura: ${p.subscriptionId}' : ''}',
              ),
              isThreeLine: true,
              trailing: p.paidAt != null
                  ? Text(
                      '${p.paidAt!.day}/${p.paidAt!.month}/${p.paidAt!.year}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  IconData _iconForStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.succeeded:
        return Icons.check_circle;
      case PaymentStatus.refunded:
        return Icons.replay;
      case PaymentStatus.pending:
      case PaymentStatus.processing:
        return Icons.hourglass_empty;
      case PaymentStatus.failed:
      case PaymentStatus.canceled:
        return Icons.cancel;
    }
  }
}
