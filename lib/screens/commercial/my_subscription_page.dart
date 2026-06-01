import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/platform/platform_registry.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../data/commercial_plan_catalog.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../widgets/commercial/commercial_status_chip.dart';
import 'plans_page.dart';

/// Tela "Minha Assinatura" — plano, datas, status e rastreamento comercial.
class MySubscriptionPage extends StatelessWidget {
  const MySubscriptionPage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Assinatura'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<CommercialAccessSnapshot>(
        stream: service.watchAccess(user.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final access = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(access: access),
              const SizedBox(height: 16),
              _DetailsCard(access: access),
              if (access.entitlements.isNotEmpty) ...[
                const SizedBox(height: 16),
                _EntitlementsCard(access: access),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlansPage()),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Ver planos disponíveis'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.access});

  final CommercialAccessSnapshot access;

  @override
  Widget build(BuildContext context) {
    final planName = access.plan?.name ??
        (access.displayStatus == SubscriptionDisplayStatus.free
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
                CommercialStatusChip(status: access.displayStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _statusDescription(access.displayStatus),
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _statusDescription(SubscriptionDisplayStatus status) {
    switch (status) {
      case SubscriptionDisplayStatus.free:
        return 'Você está no plano gratuito com acesso aos recursos essenciais.';
      case SubscriptionDisplayStatus.active:
        return 'Sua assinatura Premium está ativa.';
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
  const _DetailsCard({required this.access});

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
    if (access.displayStatus == SubscriptionDisplayStatus.free) {
      return CommercialPlanCatalog.freePlan.name;
    }
    return access.plan?.name ?? 'Premium';
  }

  String _formatExpiry() {
    if (access.displayStatus == SubscriptionDisplayStatus.lifetime) {
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
