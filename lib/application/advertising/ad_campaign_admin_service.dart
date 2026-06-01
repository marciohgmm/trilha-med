import '../../core/advertising/advertising_enums.dart';
import '../../core/audit/audit_event_type.dart';
import '../../domain/platform/models/ad_campaign.dart';
import '../../domain/platform/repositories/platform_repository_contracts.dart';
import '../platform/platform_audit_service.dart';

/// CRUD e ações administrativas de campanhas.
class AdCampaignAdminService {
  AdCampaignAdminService({
    required AdCampaignRepository campaignRepo,
    required PlatformAuditService audit,
  })  : _campaignRepo = campaignRepo,
        _audit = audit;

  final AdCampaignRepository _campaignRepo;
  final PlatformAuditService _audit;

  Future<String> save({
    required String actorUserId,
    required AdCampaign campaign,
  }) async {
    final id = await _campaignRepo.save(campaign);
    await _audit.log(
      eventType: AuditEventType.adminAction,
      actorUserId: actorUserId,
      entityType: 'ad_campaign',
      entityId: id,
      metadata: {'action': campaign.id.isEmpty ? 'create' : 'update'},
    );
    return id;
  }

  Future<void> pause({
    required String actorUserId,
    required AdCampaign campaign,
  }) async {
    await _campaignRepo.save(
      campaign.copyWith(adminStatus: AdCampaignAdminStatus.paused),
    );
    await _audit.log(
      eventType: AuditEventType.adminAction,
      actorUserId: actorUserId,
      entityType: 'ad_campaign',
      entityId: campaign.id,
      metadata: {'action': 'pause'},
    );
  }

  Future<void> resume({
    required String actorUserId,
    required AdCampaign campaign,
  }) async {
    await _campaignRepo.save(
      campaign.copyWith(adminStatus: AdCampaignAdminStatus.active),
    );
    await _audit.log(
      eventType: AuditEventType.adminAction,
      actorUserId: actorUserId,
      entityType: 'ad_campaign',
      entityId: campaign.id,
      metadata: {'action': 'resume'},
    );
  }

  Future<void> end({
    required String actorUserId,
    required AdCampaign campaign,
  }) async {
    await _campaignRepo.save(
      campaign.copyWith(adminStatus: AdCampaignAdminStatus.ended),
    );
    await _audit.log(
      eventType: AuditEventType.adminAction,
      actorUserId: actorUserId,
      entityType: 'ad_campaign',
      entityId: campaign.id,
      metadata: {'action': 'end'},
    );
  }

  Future<void> delete({
    required String actorUserId,
    required String campaignId,
  }) async {
    await _campaignRepo.delete(campaignId);
    await _audit.log(
      eventType: AuditEventType.adminAction,
      actorUserId: actorUserId,
      entityType: 'ad_campaign',
      entityId: campaignId,
      metadata: {'action': 'delete'},
    );
  }
}
