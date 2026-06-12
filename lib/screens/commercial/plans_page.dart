import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/commercial/mercado_pago_checkout_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../core/analytics/analytics_feature_tracker.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../data/commercial_plan_catalog.dart';
import '../../data/commercial_plan_presentation.dart';
import '../../domain/platform/models/subscription_plan.dart';
import '../../models/app_access_config_model.dart';
import '../../services/access/app_access_config_service.dart';
import '../../services/analytics/app_analytics_service.dart';
import '../login_page.dart';

/// Tela de planos — Gratuito vs Premium + checkout Mercado Pago.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> with WidgetsBindingObserver {
  static const _brand = Color(0xFF1E3A8A);

  bool _checkoutLoading = false;
  final _couponController = TextEditingController();
  String _billingPeriod = 'monthly';
  DateTime? _checkoutOpenedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsFeatures.plansView(
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _couponController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!kIsWeb || _checkoutOpenedAt == null) return;
    final elapsed = DateTime.now().difference(_checkoutOpenedAt!);
    if (elapsed > const Duration(minutes: 15)) return;
    _runReconcileQuietly();
  }

  Future<void> _runReconcileQuietly() async {
    try {
      await PlatformRegistry.instance.mercadoPagoCheckout.reconcileMyPayments();
    } catch (_) {}
  }

  void _schedulePaymentReconciliation() {
    _checkoutOpenedAt = DateTime.now();

    Future<void>.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      await _runReconcileQuietly();
    });

    if (kIsWeb) {
      Future<void>.delayed(const Duration(seconds: 40), () async {
        if (!mounted) return;
        await _runReconcileQuietly();
      });
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
        duration: Duration(seconds: error ? 5 : 4),
      ),
    );
  }

  Future<void> _startCheckout(SubscriptionPlan plan) async {
    if (_checkoutLoading) return;

    final checkout = PlatformRegistry.instance.mercadoPagoCheckout;
    final user = await checkout.resolveCheckoutUser();
    if (user == null) {
      _showMessage('Faça login para assinar o Premium.', error: true);
      return;
    }

    final pricing = CommercialPlanCatalog.pricingFor(plan);
    if (!pricing.configured) {
      _showMessage(
        'Preços não configurados. Peça ao administrador: Painel Mestre → Planos.',
        error: true,
      );
      return;
    }

    final period = _effectiveBillingPeriod(pricing);
    final couponCode = _couponController.text.trim();

    final amount = period == 'yearly'
        ? plan.priceYearly
        : plan.priceMonthly;
    if (amount <= 0) {
      _showMessage('Selecione uma periodicidade com preço válido.', error: true);
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final result = await checkout.createCheckout(
        planId: plan.id,
        billingPeriod: period,
        couponCode: couponCode.isEmpty ? null : couponCode,
      );

      await checkout.openCheckoutUrl(result.checkoutUrl);

      await AppAnalyticsService.instance.logCheckoutStart(
        userId: user.uid,
        planId: plan.id,
        billingPeriod: period,
        amount: result.amount > 0 ? result.amount : amount,
        couponCode: couponCode.isEmpty ? null : couponCode,
        paymentId: result.paymentId,
      );

      _showMessage(
        'Pagamento aberto no Mercado Pago. Sua assinatura será ativada após a confirmação.',
      );
      _schedulePaymentReconciliation();
    } on MercadoPagoCheckoutException catch (e) {
      _showMessage(e.message, error: true);
    } catch (e) {
      _showMessage('Erro ao iniciar pagamento: $e', error: true);
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  String _effectiveBillingPeriod(PremiumPricingDisplay pricing) {
    if (_billingPeriod == 'yearly' && pricing.hasYearly) return 'yearly';
    if (_billingPeriod == 'monthly' && pricing.hasMonthly) return 'monthly';
    if (pricing.hasMonthly) return 'monthly';
    if (pricing.hasYearly) return 'yearly';
    return _billingPeriod;
  }

  SubscriptionPlan? _resolvePremiumFromFirestore(List<SubscriptionPlan>? plans) {
    if (plans == null || plans.isEmpty) return null;
    for (final p in plans) {
      if (p.tier == PlanTier.premium) return p;
    }
    return plans.first;
  }

  String? _plansLoadIssue(AsyncSnapshot<List<SubscriptionPlan>> snap) {
    if (snap.hasError) {
      final err = snap.error.toString();
      if (err.contains('index') || err.contains('FAILED_PRECONDITION')) {
        return 'Índice Firestore pendente. Peça ao admin: firebase deploy --only firestore:indexes';
      }
      if (err.contains('permission') || err.contains('PERMISSION_DENIED')) {
        return 'Sem permissão para ler os planos. Confirme login e deploy das regras Firestore.';
      }
      return 'Erro ao carregar planos: $err';
    }
    if (snap.hasData && snap.data!.isEmpty) {
      return 'Nenhum plano ativo encontrado. Painel Mestre → Planos: ligue "Ativo", '
          'tier Premium, preço mensal ou anual > 0 e salve de novo (grava isActive no Firestore).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final repos = PlatformRegistry.instance.repositories;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Planos Premium'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting &&
              authSnap.data == null &&
              FirebaseAuth.instance.currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authSnap.data ?? FirebaseAuth.instance.currentUser;
          final signedIn = user != null;

          return StreamBuilder<AppAccessConfigModel>(
            stream: AppAccessConfigService.instance.watch(),
            builder: (context, accessSnap) {
              final accessConfig = accessSnap.data;

              return StreamBuilder<List<SubscriptionPlan>>(
                stream: signedIn ? repos.subscriptionPlans.watchActivePlans() : null,
                builder: (context, snap) {
              if (signedIn &&
                  snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData &&
                  !snap.hasError) {
                return const Center(child: CircularProgressIndicator());
              }

              final loadIssue = signedIn ? _plansLoadIssue(snap) : null;
              final free = CommercialPlanCatalog.freePlan;
              final premiumFromDb = signedIn
                  ? _resolvePremiumFromFirestore(snap.data)
                  : null;

              final premiumPlan = premiumFromDb ??
                  SubscriptionPlan(
                    id: 'preview_only',
                    name: 'Premium',
                    description:
                        'Acesso completo para acelerar sua preparação para o Revalida.',
                    tier: PlanTier.premium,
                    benefitLabels:
                        CommercialPlanCatalog.defaultPremiumBenefits,
                    isActive: true,
                    sortOrder: 1,
                  );

              final pricing = CommercialPlanCatalog.pricingFor(premiumPlan);
              final canPurchase =
                  signedIn && premiumFromDb != null && pricing.configured;
              final comparisonRows = CommercialPlanCatalog.comparisonForDisplay(
                accessConfig: accessConfig,
                premiumPlan: premiumPlan,
              );
              final effectiveBilling = _effectiveBillingPeriod(pricing);
              final wrongTier = premiumFromDb != null &&
                  premiumFromDb.tier != PlanTier.premium;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    'Desbloqueie todo o potencial do Trilha Med',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _brand,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signedIn
                        ? 'Pagamento seguro via Mercado Pago. Cancele quando quiser.'
                        : 'Entre na sua conta para assinar.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  if (loadIssue != null) ...[
                    const SizedBox(height: 12),
                    _DiagnosticBanner(message: loadIssue),
                  ],
                  if (wrongTier) ...[
                    const SizedBox(height: 12),
                    _DiagnosticBanner(
                      message:
                          'O plano "${premiumFromDb.name}" está com tier '
                          '"${premiumFromDb.tier.label}". Edite em Painel Mestre → Planos '
                          'e defina tier Premium.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PremiumOfferCard(
                    plan: premiumPlan,
                    pricing: pricing,
                    benefits: CommercialPlanCatalog.benefitsForPlan(premiumPlan),
                    signedIn: signedIn,
                    canPurchase: canPurchase,
                    loading: _checkoutLoading,
                    billingPeriod: effectiveBilling,
                    onBillingPeriodChanged: (v) {
                      if (!_checkoutLoading) setState(() => _billingPeriod = v);
                    },
                    couponController: _couponController,
                    onCheckout: () => _startCheckout(premiumFromDb!),
                    onLogin: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    missingPlanInDb: signedIn && premiumFromDb == null,
                    planDocumentId: premiumFromDb?.id,
                  ),
                  const SizedBox(height: 20),
                  _CompactPlanCard(
                    title: free.name,
                    subtitle: 'Para começar a estudar',
                    priceLabel: 'Grátis',
                    benefits: CommercialPlanCatalog.benefitsForPlan(free),
                  ),
                  const SizedBox(height: 28),
                  _BenefitsComparisonTable(rows: comparisonRows),
                  if (accessConfig != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Comparação sincronizada com Painel Mestre → Gratuito vs Premium.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Pagamento processado pelo Mercado Pago. Após aprovação, o Premium '
                    'é ativado automaticamente na sua conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PremiumOfferCard extends StatelessWidget {
  const _PremiumOfferCard({
    required this.plan,
    required this.pricing,
    required this.benefits,
    required this.signedIn,
    required this.canPurchase,
    required this.loading,
    required this.billingPeriod,
    required this.onBillingPeriodChanged,
    required this.couponController,
    required this.onCheckout,
    required this.onLogin,
    required this.missingPlanInDb,
    this.planDocumentId,
  });

  final SubscriptionPlan plan;
  final PremiumPricingDisplay pricing;
  final List<String> benefits;
  final bool signedIn;
  final bool canPurchase;
  final bool loading;
  final String billingPeriod;
  final ValueChanged<String> onBillingPeriodChanged;
  final TextEditingController couponController;
  final VoidCallback onCheckout;
  final VoidCallback onLogin;
  final bool missingPlanInDb;
  final String? planDocumentId;

  static const _brand = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final showMonthly = pricing.hasMonthly;
    final showYearly = pricing.hasYearly;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _brand, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFEEF2FF),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MAIS ESCOLHIDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.workspace_premium, color: _brand, size: 32),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _brand,
              ),
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
            const SizedBox(height: 20),
            if (pricing.configured) ...[
              Text(
                billingPeriod == 'yearly' && showYearly
                    ? pricing.formatMoney(pricing.priceYearly)
                    : pricing.formatMoney(
                        showMonthly ? pricing.priceMonthly : pricing.priceYearly,
                      ),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                billingPeriod == 'yearly' && showYearly
                    ? 'pagamento único por 12 meses'
                    : 'por mês · cobrança recorrente',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showMonthly && showYearly) ...[
                const SizedBox(height: 4),
                Text(
                  'ou ${pricing.formatMoney(pricing.priceYearly)}/ano',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ] else
              Text(
                'Preço em configuração',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            if (showMonthly && showYearly) ...[
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'monthly',
                    label: Text('Mensal ${pricing.formatMoney(pricing.priceMonthly)}'),
                    enabled: !loading,
                  ),
                  ButtonSegment(
                    value: 'yearly',
                    label: Text('Anual ${pricing.formatMoney(pricing.priceYearly)}'),
                    enabled: !loading,
                  ),
                ],
                selected: {billingPeriod},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) onBillingPeriodChanged(set.first);
                },
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'O que você ganha',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            ...benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: _brand, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b, style: const TextStyle(height: 1.3))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!signedIn) ...[
              FilledButton.icon(
                onPressed: loading ? null : onLogin,
                icon: const Icon(Icons.login),
                label: const Text('Entrar para assinar'),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              TextField(
                controller: couponController,
                enabled: !loading,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Cupom de desconto (opcional)',
                  hintText: 'Ex.: PROMO10',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (missingPlanInDb) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Plano Premium não encontrado para sua conta.\n\n'
                    'Checklist (Painel Mestre → Planos):\n'
                    '• Plano com interruptor "Ativo" ligado\n'
                    '• Tier = Premium\n'
                    '• Preço mensal e/ou anual maior que zero\n'
                    '• Salvar de novo (grava isActive no Firestore)\n\n'
                    'Depois: saia e entre na tela de planos ou reinicie o app.',
                  ),
                ),
              ] else if (!pricing.configured) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Defina preço mensal e/ou anual no Painel Mestre → Planos '
                    'para habilitar a compra.',
                  ),
                ),
              ] else ...[
                FilledButton(
                  onPressed: (loading || !canPurchase) ? null : onCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          pricing.ctaLabel(billingPeriod),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Você será redirecionado ao Mercado Pago para concluir o pagamento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (planDocumentId != null && planDocumentId!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Plano no sistema: $planDocumentId',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactPlanCard extends StatelessWidget {
  const _CompactPlanCard({
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.benefits,
  });

  final String title;
  final String subtitle;
  final String priceLabel;
  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text(
                  priceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...benefits.take(4).map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(b, style: TextStyle(color: Colors.grey.shade800)),
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
}

class _DiagnosticBanner extends StatelessWidget {
  const _DiagnosticBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.orange.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsComparisonTable extends StatelessWidget {
  const _BenefitsComparisonTable({required this.rows});

  final List<PlanBenefitComparisonRow> rows;

  static const _brand = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare os planos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _brand,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No Premium, tudo do Gratuito está incluído, mais recursos exclusivos.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Table(
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
                    padding: EdgeInsets.all(10),
                    child: Text('Benefício', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Gratuito', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ...rows.map((row) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(row.benefit),
                    ),
                    _cell(row.includedInFree, row.freeText),
                    _cell(row.includedInPremium, row.premiumText),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(bool included, String? text) {
    if (text != null && text.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: included ? const Color(0xFF059669) : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return _cellIcon(included);
  }

  Widget _cellIcon(bool included) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(
        included ? Icons.check_circle : Icons.remove_circle_outline,
        color: included ? const Color(0xFF059669) : Colors.grey.shade400,
        size: 22,
      ),
    );
  }
}
