import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/platform/platform_registry.dart';
import '../../services/analytics/app_analytics_service.dart';
import '../../utils/checkout_route_parser.dart';
import 'my_subscription_page.dart';

enum CheckoutReturnStatus { success, pending, failure }

enum _SuccessConfirmationPhase {
  confirming,
  activated,
  stillProcessing,
}

/// Página exibida após retorno do Checkout Pro (deep link / web).
class CheckoutReturnPage extends StatefulWidget {
  const CheckoutReturnPage({
    super.key,
    required this.status,
    this.planId,
    this.paymentId,
    this.amount,
    this.billingPeriod,
  });

  factory CheckoutReturnPage.fromRouteArgs(CheckoutRouteArgs args) {
    return CheckoutReturnPage(
      status: args.status,
      planId: args.planId,
      paymentId: args.paymentId,
      amount: args.amount,
      billingPeriod: args.billingPeriod,
    );
  }

  final CheckoutReturnStatus status;
  final String? planId;
  final String? paymentId;
  final double? amount;
  final String? billingPeriod;

  @override
  State<CheckoutReturnPage> createState() => _CheckoutReturnPageState();
}

class _CheckoutReturnPageState extends State<CheckoutReturnPage> {
  static const _brand = Color(0xFF1E3A8A);

  _SuccessConfirmationPhase? _successPhase;
  bool _confirmationStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPageReady());
  }

  Future<void> _onPageReady() async {
    if (widget.status == CheckoutReturnStatus.success) {
      await _confirmPremiumOnServer();
      return;
    }
    await _logReturnAnalytics(premiumConfirmed: false);
  }

  Future<void> _confirmPremiumOnServer() async {
    if (_confirmationStarted) return;
    _confirmationStarted = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _successPhase = _SuccessConfirmationPhase.stillProcessing);
      }
      return;
    }

    if (mounted) {
      setState(() => _successPhase = _SuccessConfirmationPhase.confirming);
    }

    final checkout = PlatformRegistry.instance.mercadoPagoCheckout;
    final access = PlatformRegistry.instance.commercialAccess;

    final result = await checkout.reconcileAndWaitForPremium(
      userId: user.uid,
      commercialAccess: access,
    );

    if (!mounted) return;

    if (result.premiumActive) {
      setState(() => _successPhase = _SuccessConfirmationPhase.activated);
      await _logReturnAnalytics(premiumConfirmed: true);
    } else {
      setState(() => _successPhase = _SuccessConfirmationPhase.stillProcessing);
      await _logReturnAnalytics(premiumConfirmed: false);
    }
  }

  Future<void> _logReturnAnalytics({required bool premiumConfirmed}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    switch (widget.status) {
      case CheckoutReturnStatus.success:
        if (premiumConfirmed) {
          await AppAnalyticsService.instance.logPurchaseApproved(
            userId: user.uid,
            planId: widget.planId ?? 'premium',
            amount: widget.amount ?? 0,
            paymentId: widget.paymentId,
            billingPeriod: widget.billingPeriod,
          );
        } else {
          await AppAnalyticsService.instance.logPurchasePending(
            userId: user.uid,
            paymentId: widget.paymentId,
          );
        }
      case CheckoutReturnStatus.pending:
        await AppAnalyticsService.instance.logPurchasePending(
          userId: user.uid,
          paymentId: widget.paymentId,
        );
      case CheckoutReturnStatus.failure:
        await AppAnalyticsService.instance.logPurchaseCancelled(
          userId: user.uid,
          planId: widget.planId,
          paymentId: widget.paymentId,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (widget.status) {
          CheckoutReturnStatus.success => _buildSuccessBody(context),
          CheckoutReturnStatus.pending => _buildStaticBody(
              title: 'Pagamento pendente',
              message:
                  'Assim que o Mercado Pago confirmar, sua assinatura será ativada.',
              icon: Icons.hourglass_top,
              color: const Color(0xFFD97706),
            ),
          CheckoutReturnStatus.failure => _buildStaticBody(
              title: 'Pagamento não concluído',
              message: 'Você pode tentar novamente em Planos quando quiser.',
              icon: Icons.error_outline,
              color: const Color(0xFFB45309),
            ),
        },
      ),
    );
  }

  Widget _buildSuccessBody(BuildContext context) {
    final phase = _successPhase ?? _SuccessConfirmationPhase.confirming;

    final (title, message, icon, color, showSpinner) = switch (phase) {
      _SuccessConfirmationPhase.confirming => (
          'Confirmando seu pagamento...',
          'Estamos verificando sua assinatura Premium com o Mercado Pago. '
              'Isso costuma levar poucos segundos.',
          Icons.sync,
          _brand,
          true,
        ),
      _SuccessConfirmationPhase.activated => (
          'Premium ativado com sucesso',
          'Sua assinatura Premium já está ativa nesta conta. '
              'Aproveite todos os recursos liberados.',
          Icons.check_circle_outline,
          const Color(0xFF059669),
          false,
        ),
      _SuccessConfirmationPhase.stillProcessing => (
          'Pagamento recebido',
          'Pagamento recebido, ainda processando. '
              'Confira em Minha Assinatura em instantes.',
          Icons.schedule,
          const Color(0xFFD97706),
          false,
        ),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showSpinner) ...[
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ] else
          Icon(icon, size: 72, color: color),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: phase == _SuccessConfirmationPhase.confirming
              ? null
              : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const MySubscriptionPage(),
                    ),
                  ),
          style: FilledButton.styleFrom(backgroundColor: _brand),
          child: Text(
            phase == _SuccessConfirmationPhase.activated
                ? 'Ir para Minha Assinatura'
                : 'Ver minha assinatura',
          ),
        ),
      ],
    );
  }

  Widget _buildStaticBody({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: color),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
          ),
          style: FilledButton.styleFrom(backgroundColor: _brand),
          child: const Text('Ver minha assinatura'),
        ),
      ],
    );
  }
}
