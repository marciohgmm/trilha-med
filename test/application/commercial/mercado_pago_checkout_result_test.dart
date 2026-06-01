import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/application/commercial/mercado_pago_checkout_service.dart';

void main() {
  group('MercadoPagoCheckoutResult', () {
    test('fromMap parseia resposta da Cloud Function', () {
      final result = MercadoPagoCheckoutResult.fromMap({
        'paymentId': 'pay_123',
        'preferenceId': 'pref_456',
        'checkoutUrl': 'https://mp.test/checkout',
        'amount': 49.9,
        'currency': 'BRL',
        'billingPeriod': 'monthly',
      });

      expect(result.paymentId, 'pay_123');
      expect(result.preferenceId, 'pref_456');
      expect(result.checkoutUrl, 'https://mp.test/checkout');
      expect(result.amount, 49.9);
      expect(result.currency, 'BRL');
      expect(result.billingPeriod, 'monthly');
    });

    test('fromMap tolera campos ausentes', () {
      final result = MercadoPagoCheckoutResult.fromMap({});
      expect(result.paymentId, '');
      expect(result.amount, 0);
      expect(result.currency, 'BRL');
    });
  });
}
