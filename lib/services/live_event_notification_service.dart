import 'package:cloud_functions/cloud_functions.dart';

import '../core/push/push_notification_types.dart';

/// Notificações push de eventos ao vivo — delega ao backend FCM.
class LiveEventNotificationService {
  LiveEventNotificationService._();
  static final LiveEventNotificationService instance =
      LiveEventNotificationService._();

  final _functions =
      FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  Future<void> scheduleEventReminders({
    required String eventId,
    required DateTime scheduledAt,
  }) async {
    try {
      final callable = _functions.httpsCallable('scheduleLiveEventReminders');
      await callable.call({
        'eventId': eventId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      });
    } catch (_) {
      // Backend opcional até deploy das functions.
    }
  }

  Future<void> notifyEventLive(String eventId) async {
    await _triggerEventPush(eventId: eventId, phase: 'live');
  }

  Future<void> notifyUserEliminated(String userId, String eventId) async {
    try {
      final callable = _functions.httpsCallable('notifyLiveEventUser');
      await callable.call({
        'eventId': eventId,
        'userId': userId,
        'phase': 'eliminated',
      });
    } catch (_) {}
  }

  Future<void> notifyEventEnded(String eventId) async {
    await _triggerEventPush(eventId: eventId, phase: 'ended');
  }

  Future<void> _triggerEventPush({
    required String eventId,
    required String phase,
  }) async {
    try {
      final callable = _functions.httpsCallable('notifyLiveEventBroadcast');
      await callable.call({
        'eventId': eventId,
        'phase': phase,
        'type': PushNotificationType.liveEvent,
      });
    } catch (_) {}
  }
}
