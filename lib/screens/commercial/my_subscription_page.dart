import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/platform/platform_registry.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../data/commercial_plan_catalog.dart';
import '../../domain/platform/enums/platform_enums.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../domain/platform/models/subscription.dart';
import '../../widgets/commercial/commercial_status_chip.dart';
import 'plans_page.dart';

/// Tela "Minha Assinatura" — plano, datas, status e rastreamento comercial.
class MySubscriptionPage extends StatefulWidget {
  const MySubscriptionPage({super.key});

  @override
  State<MySubscriptionPage> createState() => _MySubscriptionPageState();
}

class _MySubscriptionPageState extends State<MySubscriptionPage> {
  bool _refreshingStatus = false;

  Future<void> _refreshPaymentStatus() async {
    if (_refreshingStatus) return;
    setState(() => _refreshingStatus = true);
    try {
      await PlatformRegistry.instance.mercadoPagoCheckout.reconcileMyPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status atualizado. Se o pagamento foi aprovado, o Premium aparecerá em instantes.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Minha Assinatura'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Faça login para ver sua assinatura.')),
      );
    }

    final service = PlatformRegistry.instance.commercialAccess;
    final subscriptions =
        PlatformRegistry.instance.repositories.subscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Assinatura'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar status',
            onPressed: _refreshingStatus ? null : _refreshPaymentStatus,
            icon: _refreshingStatus
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: subscriptions.watchForUser(user.uid, limit: 15),
        builder: (context, subsSnap) {
          if (subsSnap.hasError) {
            return Center(child: Text('Erro: ${subsSnap.error}'));
          }

          final pastDueSub = _findPastDueSubscription(subsSnap.data ?? []);

          return StreamBuilder<CommercialAccessSnapshot>(
            stream: service.watchAccess(user.uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erro: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final access = snap.data!;
              final uiStatus = pastDueSub != null
                  ? SubscriptionDisplayStatus.pastDue
                  : access.displayStatus;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pastDueSub != null) ...[
                    _PastDueAlertCard(
                      onRegularize: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlansPage()),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _StatusCard(access: access, displayStatus: uiStatus),
                  const SizedBox(height: 16),
                  _DetailsCard(access: access, displayStatus: uiStatus),
                  if (access.entitlements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _EntitlementsCard(access: access),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _refreshingStatus ? null : _refreshPaymentStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar status'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlansPage()),
                    ),
                    icon: const Icon(Icons.workspace_premium),
                    label: Text(
                      pastDueSub != null
                          ? 'Regularizar pagamento'
                          : 'Ver planos disponíveis',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

Subscription? _findPastDueSubscription(List<Subscription> subscriptions) {
  for (final s in subscriptions) {
    if (s.status == SubscriptionStatus.pastDue) return s;
  }
  return null;
}

class _PastDueAlertCard extends StatelessWidget {
  const _PastDueAlertCard({required this.onRegularize});

  final VoidCallback onRegularize;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF3C7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Text(
                  'Pagamento em atraso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Identificamos pendência no pagamento da assinatura. '
              'Regularize no Mercado Pago para evitar interrupção do Premium.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRegularize,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
              ),
              child: const Text('Regularizar pagamento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.access,
    required this.displayStatus,
  });

  final CommercialAccessSnapshot access;
  final SubscriptionDisplayStatus displayStatus;

  @override
  Widget build(BuildContext context) {
    final planName = access.plan?.name ??
        (displayStatus == SubscriptionDisplayStatus.free
            ? CommercialPlanCatalog.freePlan.name
            : 'Premium');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    planName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CommercialStatusChip(status: displayStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _statusDescription(displayStatus, access),
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _statusDescription(
    SubscriptionDisplayStatus status,
    CommercialAccessSnapshot access,
  ) {
    switch (status) {
      case SubscriptionDisplayStatus.free:
        return 'Você está no plano gratuito com acesso aos recursos essenciais.';
      case SubscriptionDisplayStatus.active:
        return 'Sua assinatura Premium está ativa.';
      case SubscriptionDisplayStatus.pastDue:
        if (access.hasPremiumAccess) {
          return 'Há pendência no pagamento. Seu acesso Premium pode continuar '
              'ativo por enquanto — regularize o quanto antes.';
        }
        return 'Pagamento em atraso. Regularize para manter o Premium.';
      case SubscriptionDisplayStatus.expired:
        return 'Sua assinatura expirou. Renove para continuar com benefícios Premium.';
      case SubscriptionDisplayStatus.lifetime:
        return 'Você possui acesso Premium vitalício.';
      case SubscriptionDisplayStatus.courtesy:
        return 'Acesso concedido por cortesia da equipe.';
      case SubscriptionDisplayStatus.beta:
        return 'Acesso beta tester — obrigado por testar novos recursos!';
    }
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.access,
    required this.displayStatus,
  });

  final CommercialAccessSnapshot access;
  final SubscriptionDisplayStatus displayStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const Divider(),
            _detailRow('Plano atual', _planLabel()),
            _detailRow('Data de início', _formatDate(access.startedAt)),
            _detailRow('Data de expiração', _formatExpiry()),
            if (access.subscription?.grantSource != null)
              _detailRow(
                'Origem',
                access.subscription!.grantSource!.label,
              ),
            if (access.subscription?.sellerId != null &&
                access.subscription!.sellerId!.isNotEmpty)
              _detailRow('Vendedor', access.subscription!.sellerId!),
            if (access.subscription?.affiliateId != null &&
                access.subscription!.affiliateId!.isNotEmpty)
              _detailRow('Afiliado', access.subscription!.affiliateId!),
            if (access.subscription?.couponId != null &&
                access.subscription!.couponId!.isNotEmpty)
              _detailRow('Cupom', access.subscription!.couponId!),
          ],
        ),
      ),
    );
  }

  String _planLabel() {
    if (displayStatus == SubscriptionDisplayStatus.free) {
      return CommercialPlanCatalog.freePlan.name;
    }
    return access.plan?.name ?? 'Premium';
  }

  String _formatExpiry() {
    if (displayStatus == SubscriptionDisplayStatus.lifetime) {
      return 'Vitalício';
    }
    return _formatDate(access.expiresAt);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _EntitlementsCard extends StatelessWidget {
  const _EntitlementsCard({required this.access});

  final CommercialAccessSnapshot access;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entitlements ativos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const Divider(),
            ...access.entitlements.where((e) => e.isValidNow).map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_user, size: 20),
                    title: Text(e.key.label),
                    subtitle: Text(
                      e.expiresAt != null
                          ? 'Expira: ${_fmt(e.expiresAt!)}'
                          : 'Sem expiração',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}
