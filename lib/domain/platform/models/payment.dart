import '../../../core/base/firestore_entity.dart';
import '../enums/platform_enums.dart';

/// Pagamento (`platform_payments`).
class Payment implements FirestoreEntity {
  @override
  final String id;
  final String userId;
  final String? subscriptionId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final PaymentProvider provider;
  final String? providerPaymentId;
  final String? couponId;
  final String? sellerId;
  final String? affiliateId;
  final DateTime? paidAt;
  final Map<String, dynamic> metadata;

  const Payment({
    required this.id,
    required this.userId,
    this.subscriptionId,
    required this.amount,
    this.currency = 'BRL',
    this.status = PaymentStatus.pending,
    this.provider = PaymentProvider.manual,
    this.providerPaymentId,
    this.couponId,
    this.sellerId,
    this.affiliateId,
    this.paidAt,
    this.metadata = const {},
  });

  factory Payment.fromDoc(String id, Map<String, dynamic> d) {
    return Payment(
      id: id,
      userId: d['userId']?.toString() ?? '',
      subscriptionId: d['subscriptionId']?.toString(),
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency']?.toString() ?? 'BRL',
      status: PaymentStatus.fromKey(d['status']?.toString()),
      provider: PaymentProvider.fromKey(d['provider']?.toString()),
      providerPaymentId: d['providerPaymentId']?.toString(),
      couponId: d['couponId']?.toString(),
      sellerId: d['sellerId']?.toString(),
      affiliateId: d['affiliateId']?.toString(),
      paidAt: FirestoreDates.from(d['paidAt']),
      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        'amount': amount,
        'currency': currency,
        'status': status.key,
        'provider': provider.key,
        if (providerPaymentId != null) 'providerPaymentId': providerPaymentId,
        if (couponId != null) 'couponId': couponId,
        if (sellerId != null) 'sellerId': sellerId,
        if (affiliateId != null) 'affiliateId': affiliateId,
        if (paidAt != null) 'paidAt': FirestoreDates.to(paidAt),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
