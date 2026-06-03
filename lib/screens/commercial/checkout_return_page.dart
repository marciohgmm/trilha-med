import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';



import '../../services/analytics/app_analytics_service.dart';
import '../../utils/checkout_route_parser.dart';
import 'my_subscription_page.dart';

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

  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _logReturn());

  }



  Future<void> _logReturn() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;



    switch (widget.status) {

      case CheckoutReturnStatus.success:

        await AppAnalyticsService.instance.logPurchaseApproved(

          userId: user.uid,

          planId: widget.planId ?? 'premium',

          amount: widget.amount ?? 0,

          paymentId: widget.paymentId,

          billingPeriod: widget.billingPeriod,

        );

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

    final (title, message, icon, color) = switch (widget.status) {

      CheckoutReturnStatus.success => (

          'Pagamento recebido',

          'Estamos confirmando sua assinatura Premium. '

              'Pode levar alguns segundos — confira em Minha Assinatura.',

          Icons.check_circle_outline,

          const Color(0xFF059669),

        ),

      CheckoutReturnStatus.pending => (

          'Pagamento pendente',

          'Assim que o Mercado Pago confirmar, sua assinatura será ativada.',

          Icons.hourglass_top,

          const Color(0xFFD97706),

        ),

      CheckoutReturnStatus.failure => (

          'Pagamento não concluído',

          'Você pode tentar novamente em Planos quando quiser.',

          Icons.error_outline,

          const Color(0xFFB45309),

        ),

    };



    return Scaffold(

      appBar: AppBar(

        title: const Text('Checkout'),

        backgroundColor: const Color(0xFF1E3A8A),

        foregroundColor: Colors.white,

      ),

      body: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

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

              style: FilledButton.styleFrom(

                backgroundColor: const Color(0xFF1E3A8A),

              ),

              child: const Text('Ver minha assinatura'),

            ),

          ],

        ),

      ),

    );

  }

}



enum CheckoutReturnStatus { success, pending, failure }


