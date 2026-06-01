import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/push/push_notification_types.dart';

void main() {
  group('PushNotificationType', () {
    test('all contém 7 tipos', () {
      expect(PushNotificationType.all.length, 7);
    });

    test('label retorna texto legível', () {
      expect(
        PushNotificationType.label(PushNotificationType.liveEvent),
        'Eventos ao vivo',
      );
    });
  });

  group('PushAudienceSegment', () {
    test('options cobre segmentos do Painel Mestre', () {
      final keys = PushAudienceSegment.options.map((o) => o.$1).toSet();
      expect(keys.contains(PushAudienceSegment.premium), isTrue);
      expect(keys.contains(PushAudienceSegment.subscriptionExpiring), isTrue);
    });
  });
}
