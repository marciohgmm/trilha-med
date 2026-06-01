import 'package:flutter/material.dart';

import '../../core/push/push_notification_types.dart';
import '../../screens/live_events/live_event_play_page.dart';
import '../../screens/osce/osce_lobby_page.dart';
import '../../screens/commercial/plans_page.dart';
import '../../screens/commercial/my_subscription_page.dart';
import '../../screens/simulado/simulado_filtros_page.dart';

/// Navegação a partir do payload FCM (`data`).
class PushNavigationHandler {
  PushNavigationHandler._();

  static Future<void> handle(
    BuildContext context, {
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final type = data['type']?.toString() ?? '';
    final eventId = data['eventId']?.toString();
    final route = data['actionRoute']?.toString();

    if (route != null && route.isNotEmpty) {
      await _openRoute(context, userId: userId, route: route, eventId: eventId);
      return;
    }

    switch (type) {
      case PushNotificationType.flashcardReview:
        if (!context.mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      case PushNotificationType.cronogramaOverdue:
        if (!context.mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      case PushNotificationType.simuladoAvailable:
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SimuladoFiltrosPage(userId: userId),
          ),
        );
      case PushNotificationType.liveEvent:
        if (eventId != null && eventId.isNotEmpty && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveEventPlayPage(
                eventId: eventId,
                userId: userId,
                displayName: data['displayName']?.toString() ?? 'Participante',
              ),
            ),
          );
        }
      case PushNotificationType.subscriptionRenewal:
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
        );
      case PushNotificationType.promotional:
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlansPage()),
        );
      case PushNotificationType.adminBroadcast:
        if (!context.mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      default:
        break;
    }
  }

  static Future<void> _openRoute(
    BuildContext context, {
    required String userId,
    required String route,
    String? eventId,
  }) async {
    if (!context.mounted) return;
    switch (route) {
      case 'simulado':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SimuladoFiltrosPage(userId: userId),
          ),
        );
      case 'osce':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OsceLobbyPage(userId: userId),
          ),
        );
      case 'plans':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlansPage()),
        );
      case 'subscription':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
        );
      case 'live_event':
        if (eventId != null && eventId.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveEventPlayPage(
                eventId: eventId,
                userId: userId,
                displayName: 'Participante',
              ),
            ),
          );
        }
      default:
        break;
    }
  }
}
