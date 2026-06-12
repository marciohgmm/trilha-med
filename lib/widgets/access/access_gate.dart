import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/access/app_access_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../core/access/app_access_feature.dart';
import '../../domain/platform/models/commercial_access_snapshot.dart';
import '../../models/app_access_config_model.dart';
import '../../screens/commercial/plans_page.dart';
import '../../services/access/app_access_config_service.dart';

/// Controla acesso gratuito vs premium com base em assinatura + Firestore.
///
/// Exemplo:
/// ```dart
/// AccessGate(
///   feature: AppAccessFeature.medicalTools,
///   child: MedicalToolsPage(),
/// )
/// ```
class AccessGate extends StatelessWidget {
  const AccessGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
    this.userId,
    this.currentUsage,
    this.lockedTitle,
    this.lockedMessage,
    this.appAccess,
  });

  final AppAccessFeature feature;
  final Widget child;
  final Widget? fallback;
  final String? userId;
  final int? currentUsage;
  final String? lockedTitle;
  final String? lockedMessage;
  final AppAccessService? appAccess;

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return fallback ?? _LockedAccessView.signedOut();
    }

    final accessService = appAccess ??
        AppAccessService(
          commercialAccess: PlatformRegistry.instance.commercialAccess,
        );
    final commercial = PlatformRegistry.instance.commercialAccess;

    return StreamBuilder<AppAccessConfigModel>(
      stream: AppAccessConfigService.instance.watch(),
      builder: (context, configSnap) {
        final config = configSnap.data ?? AppAccessConfigService.instance.cached;

        return StreamBuilder<CommercialAccessSnapshot>(
          stream: commercial.watchAccess(uid),
          builder: (context, accessSnap) {
            if ((configSnap.connectionState == ConnectionState.waiting &&
                    !configSnap.hasData) ||
                (accessSnap.connectionState == ConnectionState.waiting &&
                    !accessSnap.hasData)) {
              return const Center(child: CircularProgressIndicator());
            }

            final snap = accessSnap.data ?? CommercialAccessSnapshot.free(uid);
            if (!config.accessEnforcementEnabled) return child;

            final decision = accessService.evaluate(
              snap: snap,
              config: config,
              feature: feature,
              currentUsage: currentUsage,
            );

            if (decision.allowed) return child;

            if (fallback != null) return fallback!;

            return _LockedAccessView(
              feature: feature,
              decision: decision,
              config: config,
              title: lockedTitle,
              message: lockedMessage,
            );
          },
        );
      },
    );
  }
}

/// Verificação imperativa sem montar widget.
class AccessGuard {
  AccessGuard._();

  static AppAccessService _access() => AppAccessService(
        commercialAccess: PlatformRegistry.instance.commercialAccess,
      );

  static Future<AppAccessDecision> evaluate(
    String userId,
    AppAccessFeature feature, {
    int? currentUsage,
  }) {
    return _access().evaluateForUser(
      userId: userId,
      feature: feature,
      currentUsage: currentUsage,
    );
  }

  static Future<bool> canAccess(
    String userId,
    AppAccessFeature feature, {
    int? currentUsage,
  }) async {
    final d = await evaluate(userId, feature, currentUsage: currentUsage);
    return d.allowed;
  }

  static Stream<bool> watchCanAccess(
    String userId,
    AppAccessFeature feature, {
    int? currentUsage,
  }) {
    return _access().watchDecision(
      userId: userId,
      feature: feature,
      currentUsage: currentUsage,
      commercialAccess: PlatformRegistry.instance.commercialAccess,
    ).map((d) => d.allowed);
  }
}

class _LockedAccessView extends StatelessWidget {
  const _LockedAccessView({
    required this.feature,
    required this.decision,
    required this.config,
    this.title,
    this.message,
  });

  const _LockedAccessView.signedOut()
      : feature = AppAccessFeature.flashcards,
        decision = null,
        config = null,
        title = null,
        message = null;

  final AppAccessFeature? feature;
  final AppAccessDecision? decision;
  final AppAccessConfigModel? config;
  final String? title;
  final String? message;

  bool get _signedOut => decision == null;

  @override
  Widget build(BuildContext context) {
    final showPadlock = _signedOut || (config?.showLockedWithPadlock ?? true);
    final showUpgrade = !_signedOut && (config?.showUpgradeButton ?? true);

    final defaultTitle = _signedOut
        ? 'Faça login para continuar'
        : (decision!.isPremiumUser
            ? 'Recurso indisponível'
            : 'Recurso Premium');

    final defaultMessage = _signedOut
        ? 'Entre na sua conta para acessar este conteúdo.'
        : _messageForDecision(decision!);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showPadlock)
              Icon(
                Icons.lock_outline,
                size: 56,
                color: Colors.grey.shade400,
              ),
            if (showPadlock) const SizedBox(height: 16),
            Text(
              title ?? defaultTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? defaultMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            if (showUpgrade && !_signedOut) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlansPage()),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Assinar Premium'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _messageForDecision(AppAccessDecision d) {
    if (d.blockedByLimit && d.freeLimit != null) {
      return 'No plano gratuito você pode usar até ${d.freeLimit} '
          '${feature?.label ?? 'itens'} de ${feature?.label ?? 'este recurso'}. '
          'Assine o Premium para acesso ilimitado.';
    }
    if (d.blockedByFeatureDisabled) {
      return '${feature?.label ?? 'Este recurso'} está disponível no Premium. '
          'Assine para desbloquear.';
    }
    return 'Assine o Premium para acessar ${feature?.label ?? 'este recurso'}.';
  }
}
