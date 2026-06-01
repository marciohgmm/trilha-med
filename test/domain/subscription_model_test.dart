import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/platform/enums/platform_enums.dart';
import 'package:flutter_application_1/domain/platform/models/subscription.dart';

void main() {
  group('Subscription', () {
    test('fromDoc parseia status e datas', () {
      final end = DateTime(2025, 12, 31);
      final sub = Subscription.fromDoc('sub1', {
        'userId': 'u1',
        'planId': 'premium',
        'status': 'active',
        'currentPeriodEnd': Timestamp.fromDate(end),
      });
      expect(sub.isActive, isTrue);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.currentPeriodEnd, end);
    });

    test('toMap inclui campos obrigatórios', () {
      const sub = Subscription(
        id: 's',
        userId: 'u',
        planId: 'p',
        status: SubscriptionStatus.trialing,
      );
      final map = sub.toMap();
      expect(map['userId'], 'u');
      expect(map['status'], 'trialing');
    });
  });
}
