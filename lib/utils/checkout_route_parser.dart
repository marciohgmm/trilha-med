import 'package:flutter/foundation.dart';

import '../screens/commercial/checkout_return_page.dart';

/// Resultado do parse de rota/deep link de retorno do Mercado Pago.
class CheckoutRouteArgs {
  const CheckoutRouteArgs({
    required this.status,
    this.planId,
    this.paymentId,
    this.amount,
    this.billingPeriod,
  });

  final CheckoutReturnStatus status;
  final String? planId;
  final String? paymentId;
  final double? amount;
  final String? billingPeriod;
}

/// Paths: `/checkout/success`, `/checkout/pending`, `/checkout/failure`.
class CheckoutRouteParser {
  CheckoutRouteParser._();

  static const checkoutPathPrefix = '/checkout/';

  static String resolveInitialRoute() {
    if (kIsWeb) {
      final path = _normalizePath(Uri.base.path);
      if (path.startsWith(checkoutPathPrefix)) return path;
    }
    return '/';
  }

  static CheckoutRouteArgs? tryParseRouteSettings(String? name) {
    if (name == null || name.isEmpty) {
      if (kIsWeb) return tryParseUri(Uri.base);
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) return tryParseUri(uri);
    }
    return tryParseUri(Uri.parse(_normalizePath(trimmed)));
  }

  static CheckoutRouteArgs? tryParseUri(Uri uri) {
    final path = _normalizePath(uri.path);
    if (!path.startsWith(checkoutPathPrefix)) return null;

    final segment = path.substring(checkoutPathPrefix.length).split('/').first;
    final status = _statusFromSegment(segment);
    if (status == null) return null;

    final q = uri.queryParameters;
    final paymentId = _firstNonEmpty([
      q['external_reference'],
      q['payment_id'],
      q['preference_id'],
      q['collection_id'],
    ]);

    final planId = _firstNonEmpty([q['plan_id'], q['planId']]);
    final billingPeriod = _firstNonEmpty([q['billing_period'], q['billingPeriod']]);

    final amountRaw = q['amount'] ?? q['transaction_amount'];
    final amount = amountRaw != null ? double.tryParse(amountRaw) : null;

    return CheckoutRouteArgs(
      status: status,
      planId: planId,
      paymentId: paymentId,
      amount: amount,
      billingPeriod: billingPeriod,
    );
  }

  static CheckoutReturnStatus? _statusFromSegment(String segment) {
    switch (segment.toLowerCase()) {
      case 'success':
        return CheckoutReturnStatus.success;
      case 'pending':
        return CheckoutReturnStatus.pending;
      case 'failure':
      case 'failed':
        return CheckoutReturnStatus.failure;
      default:
        return null;
    }
  }

  static String _normalizePath(String path) {
    var p = path.trim();
    if (p.isEmpty) return '/';
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }
}
