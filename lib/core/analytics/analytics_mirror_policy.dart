import 'analytics_events.dart';

/// Eventos espelhados no Firestore (`platform_analytics_events`).
/// Demais eventos vão apenas ao GA4.
abstract final class AnalyticsMirrorPolicy {
  AnalyticsMirrorPolicy._();

  /// Eventos críticos de negócio + sessão (1×/dia/dispositivo — retenção/DAU).
  static const mirroredEventNames = <String>{
    AnalyticsEvents.login,
    AnalyticsEvents.signUp,
    AnalyticsEvents.paywallView,
    AnalyticsEvents.checkoutStart,
    AnalyticsEvents.purchaseApproved,
    AnalyticsEvents.purchaseCancelled,
    AnalyticsEvents.sessionStart,
  };

  static bool shouldMirrorToFirestore(String eventName) =>
      mirroredEventNames.contains(eventName);
}
