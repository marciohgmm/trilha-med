import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../application/admin/admin_access_service.dart';
import '../../core/access/app_access_feature.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../models/access_usage_stats.dart';
import '../../models/app_access_config_model.dart';
import '../../services/access/app_access_config_service.dart';
import '../../services/access/access_usage_repository.dart';
import '../../services/auth/admin_auth_service.dart';
import '../commercial/commercial_access_service.dart';

/// Serviço unificado P0 — limites do gratuito + consumo de cota.
class ContentAccessService {
  ContentAccessService({
    AppAccessConfigService? configService,
    CommercialAccessService? commercialAccess,
    AccessUsageRepository? usageRepository,
    AdminAccessService? adminAccess,
  })  : _configService = configService ?? AppAccessConfigService.instance,
        _commercialAccess = commercialAccess,
        _usageRepository = usageRepository ?? AccessUsageRepository(),
        _adminAccess = adminAccess;

  static ContentAccessService get instance =>
      ContentAccessService(commercialAccess: null);

  final AppAccessConfigService _configService;
  final CommercialAccessService? _commercialAccess;
  final AccessUsageRepository _usageRepository;
  final AdminAccessService? _adminAccess;

  final Map<String, bool> _adminBypassCache = {};
  AccessUsageStats _cachedStats = const AccessUsageStats();
  String? _cachedStatsUserId;

  bool isEnforcementEnabled(AppAccessConfigModel config) {
    return config.accessEnforcementEnabled;
  }

  Future<CommercialAccessSnapshot> _accessFor(String userId) async {
    if (_commercialAccess != null) {
      return _commercialAccess!.getAccess(userId);
    }
    return CommercialAccessSnapshot.free(userId);
  }

  Future<bool> shouldBypassQuota({
    required String userId,
    required CommercialAccessSnapshot snap,
    required AppAccessConfigModel config,
  }) async {
    if (!isEnforcementEnabled(config)) return true;
    if (snap.hasPremiumAccess) return true;
    if (_adminBypassCache[userId] == true) return true;
    if (_adminBypassCache[userId] == false) return false;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ContentAccess] fail-open action=adminCheck userId=$userId '
          'reason=auth_unavailable detail=$e',
        );
      }
      _adminBypassCache[userId] = false;
      return false;
    }
    if (user?.uid != userId) {
      _adminBypassCache[userId] = false;
      return false;
    }
    if (AdminAuthService.isFounderUser(user)) {
      _adminBypassCache[userId] = true;
      return true;
    }
    final adminAccess = _adminAccess;
    if (adminAccess == null) {
      _adminBypassCache[userId] = false;
      return false;
    }
    try {
      final r = await adminAccess.resolveAdminAccess(user: user);
      _adminBypassCache[userId] = r.allowed;
      return r.allowed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ContentAccess] fail-open action=adminCheck userId=$userId '
          'reason=firestore_error detail=$e',
        );
      }
      _adminBypassCache[userId] = false;
      return false;
    }
  }

  Future<AccessUsageStats> statsFor(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStatsUserId == userId) {
      return _cachedStats;
    }
    final stats = await _usageRepository.loadStats(userId);
    _cachedStats = stats;
    _cachedStatsUserId = userId;
    return stats;
  }

  void invalidateStatsCache() {
    _cachedStatsUserId = null;
    _cachedStats = const AccessUsageStats();
  }

  int _usedForFeature(AccessUsageStats stats, AppAccessFeature feature) {
    switch (feature) {
      case AppAccessFeature.flashcards:
        return stats.flashcardsConsumed;
      case AppAccessFeature.questions:
        return stats.questionsConsumed;
      default:
        return 0;
    }
  }

  Future<ConsumeResult> evaluateFeature({
    required String userId,
    required AppAccessFeature feature,
    AppAccessConfigModel? config,
    CommercialAccessSnapshot? snap,
    AccessUsageStats? stats,
  }) async {
    final cfg = config ?? await _configService.get();
    final access = snap ?? await _accessFor(userId);

    if (!isEnforcementEnabled(cfg)) {
      return ConsumeResult.allowed(reason: ContentAccessBlockReason.enforcementOff);
    }

    if (await shouldBypassQuota(userId: userId, snap: access, config: cfg)) {
      final reason = access.hasPremiumAccess
          ? ContentAccessBlockReason.premiumBypass
          : ContentAccessBlockReason.adminBypass;
      return ConsumeResult.allowed(reason: reason);
    }

    final tier = cfg.free;
    if (!tier.isFeatureAvailable(feature, isPremiumTier: false)) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.featureDisabled,
      );
    }

    final limit = tier.limitFor(feature);
    if (limit == null || feature.limitField == null) {
      return ConsumeResult.allowed();
    }

    final usage = stats ?? await statsFor(userId);
    final used = _usedForFeature(usage, feature);
    if (used >= limit) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.limitReached,
        limit: limit,
        used: used,
      );
    }

    return ConsumeResult.allowed(limit: limit, used: used);
  }

  Future<ConsumeResult> tryConsumeFlashcard({
    required String userId,
    required String cardId,
  }) async {
    final cfg = await _configService.get();
    final access = await _accessFor(userId);
    final pre = await evaluateFeature(
      userId: userId,
      feature: AppAccessFeature.flashcards,
      config: cfg,
      snap: access,
    );

    if (!pre.allowed) {
      if (pre.reason == ContentAccessBlockReason.limitReached) {
        return pre;
      }
      if (pre.reason == ContentAccessBlockReason.featureDisabled) {
        return pre;
      }
      return ConsumeResult.allowed(
        reason: pre.reason,
        limit: pre.limit,
        used: pre.used,
      );
    }

    if (!isEnforcementEnabled(cfg) ||
        await shouldBypassQuota(userId: userId, snap: access, config: cfg)) {
      return ConsumeResult.allowed(reason: pre.reason);
    }

    final limit = cfg.free.limitFor(AppAccessFeature.flashcards)!;
    final statsBefore = await statsFor(userId, forceRefresh: true);
    final usedBefore = statsBefore.flashcardsConsumed;

    if (usedBefore >= limit) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.limitReached,
        limit: limit,
        used: usedBefore,
      );
    }

    final newly = await _usageRepository.tryMarkFlashcardConsumed(
      userId,
      cardId,
    );
    invalidateStatsCache();

    if (newly) {
      final usedAfter = usedBefore + 1;
      if (usedAfter > limit) {
        return ConsumeResult.blocked(
          reason: ContentAccessBlockReason.limitReached,
          limit: limit,
          used: usedAfter,
        );
      }
      return ConsumeResult.allowed(
        newlyConsumed: true,
        limit: limit,
        used: usedAfter,
      );
    }

    final statsAfter = await statsFor(userId, forceRefresh: true);
    final usedAfter = statsAfter.flashcardsConsumed;
    if (usedAfter >= limit && usedBefore >= limit) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.limitReached,
        limit: limit,
        used: usedAfter,
      );
    }

    return ConsumeResult.allowed(
      limit: limit,
      used: usedAfter,
      newlyConsumed: false,
    );
  }

  Future<ConsumeResult> tryConsumeQuestion({
    required String userId,
    required String questionId,
  }) async {
    final cfg = await _configService.get();
    final access = await _accessFor(userId);
    final pre = await evaluateFeature(
      userId: userId,
      feature: AppAccessFeature.questions,
      config: cfg,
      snap: access,
    );

    if (!pre.allowed) {
      if (pre.reason == ContentAccessBlockReason.limitReached ||
          pre.reason == ContentAccessBlockReason.featureDisabled) {
        return pre;
      }
      return ConsumeResult.allowed(
        reason: pre.reason,
        limit: pre.limit,
        used: pre.used,
      );
    }

    if (!isEnforcementEnabled(cfg) ||
        await shouldBypassQuota(userId: userId, snap: access, config: cfg)) {
      return ConsumeResult.allowed(reason: pre.reason);
    }

    final limit = cfg.free.limitFor(AppAccessFeature.questions)!;
    final statsBefore = await statsFor(userId, forceRefresh: true);
    final usedBefore = statsBefore.questionsConsumed;

    if (usedBefore >= limit) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.limitReached,
        limit: limit,
        used: usedBefore,
      );
    }

    final newly = await _usageRepository.tryMarkQuestionConsumed(
      userId,
      questionId,
    );
    invalidateStatsCache();

    if (newly) {
      final usedAfter = usedBefore + 1;
      if (usedAfter > limit) {
        return ConsumeResult.blocked(
          reason: ContentAccessBlockReason.limitReached,
          limit: limit,
          used: usedAfter,
        );
      }
      return ConsumeResult.allowed(
        newlyConsumed: true,
        limit: limit,
        used: usedAfter,
      );
    }

    final statsAfter = await statsFor(userId, forceRefresh: true);
    final usedAfter = statsAfter.questionsConsumed;
    if (usedAfter >= limit && usedBefore >= limit) {
      return ConsumeResult.blocked(
        reason: ContentAccessBlockReason.limitReached,
        limit: limit,
        used: usedAfter,
      );
    }

    return ConsumeResult.allowed(
      limit: limit,
      used: usedAfter,
      newlyConsumed: false,
    );
  }
}
