import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resultado do checkout Mercado Pago (Checkout Pro).
class MercadoPagoCheckoutResult {
  final String paymentId;
  final String preferenceId;
  final String checkoutUrl;
  final double amount;
  final String currency;
  final String billingPeriod;

  const MercadoPagoCheckoutResult({
    required this.paymentId,
    required this.preferenceId,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.billingPeriod,
  });

  factory MercadoPagoCheckoutResult.fromMap(Map<String, dynamic> data) {
    return MercadoPagoCheckoutResult(
      paymentId: data['paymentId']?.toString() ?? '',
      preferenceId: data['preferenceId']?.toString() ?? '',
      checkoutUrl: data['checkoutUrl']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'BRL',
      billingPeriod: data['billingPeriod']?.toString() ?? 'monthly',
    );
  }
}

/// Integração Checkout Pro via Cloud Function — sem SDK no app.
class MercadoPagoCheckoutService {
  MercadoPagoCheckoutService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  /// Cria preferência MP e abre checkout no navegador/app MP.
  Future<MercadoPagoCheckoutResult> startCheckout({
    required String planId,
    required String billingPeriod,
    String? couponCode,
    String? sellerId,
    String? affiliateId,
  }) async {
    final callable = _functions.httpsCallable('createMercadoPagoCheckout');
    final response = await callable.call<Map<String, dynamic>>({
      'planId': planId,
      'billingPeriod': billingPeriod,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (sellerId != null && sellerId.isNotEmpty) 'sellerId': sellerId,
      if (affiliateId != null && affiliateId.isNotEmpty) 'affiliateId': affiliateId,
    });

    final result = MercadoPagoCheckoutResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );

    if (result.checkoutUrl.isEmpty) {
      throw MercadoPagoCheckoutException('URL de checkout não retornada.');
    }

    final uri = Uri.parse(result.checkoutUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw MercadoPagoCheckoutException(
        'Não foi possível abrir o checkout Mercado Pago.',
      );
    }

    return result;
  }

  /// P0-4: reconcilia pagamentos do usuário com a API MP (pós-checkout / IPN perdido).
  Future<ReconcilePaymentsResult> reconcileMyPayments() async {
    final callable = _functions.httpsCallable('reconcileMyMercadoPagoPayments');
    final response = await callable.call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(response.data);
    final ids = (data['paymentIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return ReconcilePaymentsResult(
      reconciled: (data['reconciled'] as num?)?.toInt() ?? 0,
      paymentIds: ids,
    );
  }
}

class ReconcilePaymentsResult {
  final int reconciled;
  final List<String> paymentIds;

  const ReconcilePaymentsResult({
    required this.reconciled,
    required this.paymentIds,
  });
}

class MercadoPagoCheckoutException implements Exception {
  MercadoPagoCheckoutException(this.message);
  final String message;

  @override
  String toString() => message;
}
