import 'package:cloud_functions/cloud_functions.dart';

/// Envio de campanhas push via Cloud Function (Painel Mestre).
class PushCampaignAdminService {
  PushCampaignAdminService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  Future<String> createAndSendCampaign({
    required String title,
    required String body,
    required String type,
    required String audienceSegment,
    String? eventId,
    String? actionRoute,
  }) async {
    final callable = _functions.httpsCallable('createPushCampaign');
    final result = await callable.call<Map<String, dynamic>>({
      'title': title,
      'body': body,
      'type': type,
      'audienceSegment': audienceSegment,
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      if (actionRoute != null && actionRoute.isNotEmpty) 'actionRoute': actionRoute,
    });
    return result.data['campaignId']?.toString() ?? '';
  }
}
