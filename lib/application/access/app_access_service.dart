import '../../core/access/app_access_feature.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../models/app_access_config_model.dart';
import '../../models/app_access_plan_tier_model.dart';
import '../../services/access/app_access_config_service.dart';
import '../commercial/commercial_access_service.dart';

/// Resultado da verificação de acesso a uma funcionalidade.
class AppAccessDecision {
  final bool allowed;
  final bool isPremiumUser;
  final AppAccessFeature feature;
  final String? blockReason;
  final int? freeLimit;
  final int? currentUsage;

  const AppAccessDecision({
    required this.allowed,
    required this.isPremiumUser,
    required this.feature,
    this.blockReason,
    this.freeLimit,
    this.currentUsage,
  });

  bool get blockedByLimit =>
      !allowed && blockReason == 'free_limit_reached';

  bool get blockedByFeatureDisabled =>
      !allowed && blockReason == 'feature_disabled_for_tier';
}

/// Combina assinatura premium + configuração remota `app_access_config/plans`.
class AppAccessService {
  AppAccessService({
    AppAccessConfigService? configService,
    CommercialAccessService? commercialAccess,
  })  : _configService = configService ?? AppAccessConfigService.instance,
        _commercialAccess = commercialAccess;

  final AppAccessConfigService _configService;
  final CommercialAccessService? _commercialAccess;

  Stream<AppAccessConfigModel> watchConfig() => _configService.watch();

  Future<AppAccessConfigModel> getConfig() => _configService.get();

  AppAccessPlanTierModel tierForUser(
    CommercialAccessSnapshot snap,
    AppAccessConfigModel config,
  ) {
    return snap.hasPremiumAccess ? config.premium : config.free;
  }

  AppAccessDecision evaluate({
    required CommercialAccessSnapshot snap,
    required AppAccessConfigModel config,
    required AppAccessFeature feature,
    int? currentUsage,
  }) {
    final isPremium = snap.hasPremiumAccess;
    final tier = tierForUser(snap, config);

    if (!tier.isFeatureEnabled(feature)) {
      return AppAccessDecision(
        allowed: false,
        isPremiumUser: isPremium,
        feature: feature,
        blockReason: 'feature_disabled_for_tier',
        freeLimit: isPremium ? null : tier.limitFor(feature),
        currentUsage: currentUsage,
      );
    }

    if (!isPremium) {
      if (!tier.isFeatureAvailable(feature, isPremiumTier: false)) {
        return AppAccessDecision(
          allowed: false,
          isPremiumUser: false,
          feature: feature,
          blockReason: 'feature_disabled_for_tier',
          freeLimit: tier.limitFor(feature),
          currentUsage: currentUsage,
        );
      }
      final limit = tier.limitFor(feature);
      if (limit != null && limit > 0 && currentUsage != null) {
        if (currentUsage >= limit) {
          return AppAccessDecision(
            allowed: false,
            isPremiumUser: false,
            feature: feature,
            blockReason: 'free_limit_reached',
            freeLimit: limit,
            currentUsage: currentUsage,
          );
        }
      }
    }

    return AppAccessDecision(
      allowed: true,
      isPremiumUser: isPremium,
      feature: feature,
      freeLimit: isPremium ? null : tier.limitFor(feature),
      currentUsage: currentUsage,
    );
  }

  Future<AppAccessDecision> evaluateForUser({
    required String userId,
    required AppAccessFeature feature,
    int? currentUsage,
    CommercialAccessSnapshot? accessSnapshot,
    AppAccessConfigModel? config,
  }) async {
    final CommercialAccessSnapshot snap;
    if (accessSnapshot != null) {
      snap = accessSnapshot;
    } else if (_commercialAccess != null) {
      snap = await _commercialAccess!.getAccess(userId);
    } else {
      snap = CommercialAccessSnapshot.free(userId);
    }
    final cfg = config ?? await _configService.get();
    return evaluate(
      snap: snap,
      config: cfg,
      feature: feature,
      currentUsage: currentUsage,
    );
  }

  Stream<AppAccessDecision> watchDecision({
    required String userId,
    required AppAccessFeature feature,
    int? currentUsage,
    required CommercialAccessService commercialAccess,
  }) {
    return commercialAccess.watchAccess(userId).asyncMap((snap) async {
      final cfg = await _configService.get();
      return evaluate(
        snap: snap,
        config: cfg,
        feature: feature,
        currentUsage: currentUsage,
      );
    });
  }

  bool canAccessSync({
    required CommercialAccessSnapshot snap,
    required AppAccessConfigModel config,
    required AppAccessFeature feature,
    int? currentUsage,
  }) {
    return evaluate(
      snap: snap,
      config: config,
      feature: feature,
      currentUsage: currentUsage,
    ).allowed;
  }
}
