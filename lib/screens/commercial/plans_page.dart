import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/commercial/mercado_pago_checkout_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../core/analytics/analytics_feature_tracker.dart';
import '../../services/analytics/app_analytics_service.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../data/commercial_plan_catalog.dart';
import '../../domain/platform/models/subscription_plan.dart';

/// Tela pública de comparação de planos (Gratuito vs Premium) + checkout MP.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  bool _checkoutLoading = false;
  String? _couponCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsFeatures.plansView(
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    });
  }

  void _schedulePaymentReconciliation() {
    Future<void>.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      try {
        await PlatformRegistry.instance.mercadoPagoCheckout.reconcileMyPayments();
      } catch (_) {
        // Falha silenciosa — webhook agendado ou nova tentativa manual.
      }
    });
    Future<void>.delayed(const Duration(seconds: 45), () async {
      if (!mounted) return;
      try {
        await PlatformRegistry.instance.mercadoPagoCheckout.reconcileMyPayments();
      } catch (_) {}
    });
  }

  Future<void> _startCheckout(SubscriptionPlan plan, String billingPeriod) async {
    if (_checkoutLoading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para assinar o Premium.')),
      );
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final result = await PlatformRegistry.instance.mercadoPagoCheckout.startCheckout(
        planId: plan.id,
        billingPeriod: billingPeriod,
        couponCode: _couponCode,
      );
      final amount = billingPeriod == 'yearly' ? plan.priceYearly : plan.priceMonthly;
      await AppAnalyticsService.instance.logCheckoutStart(
        userId: user.uid,
        planId: plan.id,
        billingPeriod: billingPeriod,
        amount: result.amount > 0 ? result.amount : amount,
        couponCode: _couponCode,
        paymentId: result.paymentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete o pagamento no Mercado Pago. '
            'Sua assinatura será ativada em instantes.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      _schedulePaymentReconciliation();
    } on MercadoPagoCheckoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar checkout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final repos = PlatformRegistry.instance.repositories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SubscriptionPlan>>(
        stream: signedIn ? repos.subscriptionPlans.watchActivePlans() : null,
        builder: (context, snap) {
          final free = CommercialPlanCatalog.freePlan;
          SubscriptionPlan? premium;
          if (snap.hasData) {
            for (final p in snap.data!) {
              if (p.tier == PlanTier.premium) {
                premium = p;
                break;
              }
            }
            premium ??= snap.data!.isNotEmpty ? snap.data!.first : null;
          }

          final premiumPlan = premium ??
              SubscriptionPlan(
                id: 'premium',
                name: 'Premium',
                description: 'Recursos avançados para acelerar sua aprovação.',
                tier: PlanTier.premium,
                benefitLabels: CommercialPlanCatalog.defaultPremiumBenefits,
                isActive: true,
                sortOrder: 1,
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Escolha o plano ideal para sua preparação',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                signedIn
                    ? 'Assine com Mercado Pago — mensal ou anual.'
                    : 'Faça login para assinar o Premium.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              _PlanCard(
                plan: free,
                benefits: CommercialPlanCatalog.benefitsForPlan(free),
                highlighted: false,
                priceLabel: 'Grátis',
              ),
              const SizedBox(height: 16),
              _PlanCard(
                plan: premiumPlan,
                benefits: CommercialPlanCatalog.benefitsForPlan(premium),
                highlighted: true,
                priceLabel: premium != null
                    ? _formatPrice(premium)
                    : 'Consulte após login',
                checkoutActions: signedIn && premium != null
                    ? _PremiumCheckoutActions(
                        plan: premium,
                        loading: _checkoutLoading,
                        onCheckout: _startCheckout,
                        couponCode: _couponCode,
                        onCouponChanged: (v) => setState(() => _couponCode = v),
                      )
                    : null,
              ),
              const SizedBox(height: 32),
              _BenefitsComparisonTable(
                freeBenefits: CommercialPlanCatalog.benefitsForPlan(free),
                premiumBenefits: CommercialPlanCatalog.benefitsForPlan(premium),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatPrice(SubscriptionPlan plan) {
    if (plan.priceMonthly <= 0 && plan.priceYearly <= 0) {
      return 'Sob consulta';
    }
    final monthly =
        'R\$ ${plan.priceMonthly.toStringAsFixed(2).replaceAll('.', ',')}/mês';
    if (plan.priceYearly > 0) {
      final yearly =
          'R\$ ${plan.priceYearly.toStringAsFixed(2).replaceAll('.', ',')}/ano';
      return '$monthly · $yearly';
    }
    return monthly;
  }
}

class _PremiumCheckoutActions extends StatelessWidget {
  const _PremiumCheckoutActions({
    required this.plan,
    required this.loading,
    required this.onCheckout,
    this.couponCode,
    required this.onCouponChanged,
  });

  final SubscriptionPlan plan;
  final bool loading;
  final Future<void> Function(SubscriptionPlan plan, String billingPeriod) onCheckout;
  final String? couponCode;
  final ValueChanged<String?> onCouponChanged;

  @override
  Widget build(BuildContext context) {
    String brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Cupom (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onCouponChanged,
        ),
        const SizedBox(height: 12),
        if (plan.priceMonthly > 0)
          FilledButton(
            onPressed: loading ? null : () => onCheckout(plan, 'monthly'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Assinar mensal — ${brl(plan.priceMonthly)}'),
          ),
        if (plan.priceYearly > 0) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: loading ? null : () => onCheckout(plan, 'yearly'),
            child: Text('Assinar anual — ${brl(plan.priceYearly)}'),
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.benefits,
    required this.highlighted,
    required this.priceLabel,
    this.checkoutActions,
  });

  final SubscriptionPlan plan;
  final List<String> benefits;
  final bool highlighted;
  final String priceLabel;
  final Widget? checkoutActions;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: highlighted
                          ? const Color(0xFF1E3A8A)
                          : Colors.black87,
                    ),
                  ),
                ),
                if (highlighted)
                  const Chip(
                    label: Text('Recomendado'),
                    backgroundColor: Color(0xFFE0E7FF),
                  ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.description, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            Text(
              priceLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 16),
            ...benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: highlighted
                          ? const Color(0xFF1E3A8A)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
            if (checkoutActions != null) checkoutActions!,
          ],
        ),
      ),
    );
  }
}

class _BenefitsComparisonTable extends StatelessWidget {
  const _BenefitsComparisonTable({
    required this.freeBenefits,
    required this.premiumBenefits,
  });

  final List<String> freeBenefits;
  final List<String> premiumBenefits;

  @override
  Widget build(BuildContext context) {
    final allBenefits = {...freeBenefits, ...premiumBenefits}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comparação de benefícios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Benefício', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Gratuito', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...allBenefits.map((benefit) {
              final inFree = freeBenefits.contains(benefit);
              final inPremium = premiumBenefits.contains(benefit);
              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(benefit)),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      inFree ? Icons.check : Icons.close,
                      color: inFree ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      inPremium ? Icons.check : Icons.close,
                      color: inPremium ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
