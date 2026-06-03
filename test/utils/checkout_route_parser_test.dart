import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/commercial/checkout_return_page.dart';
import 'package:flutter_application_1/utils/checkout_route_parser.dart';

void main() {
  test('parse /checkout/success com external_reference', () {
    final args = CheckoutRouteParser.tryParseUri(
      Uri.parse(
        '/checkout/success?external_reference=pay_abc&plan_id=premium&billing_period=monthly',
      ),
    );
    expect(args, isNotNull);
    expect(args!.status, CheckoutReturnStatus.success);
    expect(args.paymentId, 'pay_abc');
    expect(args.planId, 'premium');
    expect(args.billingPeriod, 'monthly');
  });

  test('parse /checkout/failure sem query params', () {
    final args = CheckoutRouteParser.tryParseUri(Uri.parse('/checkout/failure'));
    expect(args?.status, CheckoutReturnStatus.failure);
    expect(args?.paymentId, isNull);
  });

  test('rota não checkout retorna null', () {
    expect(CheckoutRouteParser.tryParseUri(Uri.parse('/home')), isNull);
  });
}
