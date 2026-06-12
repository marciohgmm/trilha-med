import 'package:flutter/material.dart';

import '../../core/access/app_access_feature.dart';
import '../../models/access_usage_stats.dart';
import '../../screens/commercial/plans_page.dart';
import '../../services/access/app_access_config_service.dart';

/// UI padrão quando o gratuito atinge limite ou recurso desabilitado (P0).
class FreeLimitReachedView extends StatelessWidget {
  const FreeLimitReachedView({
    super.key,
    required this.feature,
    this.limit,
    this.used,
    this.showUpgradeButton = true,
    this.showPadlock = true,
  });

  final AppAccessFeature feature;
  final int? limit;
  final int? used;
  final bool showUpgradeButton;
  final bool showPadlock;

  static const _brand = Color(0xFF1E3A8A);

  String get _title {
    if (limit != null && limit! <= 0) {
      return '${feature.label} indisponível no plano gratuito';
    }
    return 'Limite gratuito de ${feature.label.toLowerCase()} atingido';
  }

  String get _message {
    if (limit != null && limit! <= 0) {
      return 'Este recurso não está incluído no plano gratuito. '
          'Assine o Premium para continuar estudando sem restrições.';
    }
    if (limit != null && used != null) {
      return 'Você usou $used de $limit ${feature.label.toLowerCase()} '
          'incluídos no plano gratuito. Assine o Premium para acesso ilimitado.';
    }
    return 'Assine o Premium para continuar estudando sem limites.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showPadlock)
              Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade400),
            if (showPadlock) const SizedBox(height: 16),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _brand,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            if (showUpgradeButton) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlansPage()),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Ver planos Premium'),
                style: FilledButton.styleFrom(backgroundColor: _brand),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SnackBar/dialog rápido ao bloquear resposta de questão.
Future<void> showContentAccessBlockedFeedback(
  BuildContext context, {
  required AppAccessFeature feature,
  required ConsumeResult result,
}) async {
  final config = await AppAccessConfigService.instance.get();
  if (!context.mounted) return;
  if (result.reason == ContentAccessBlockReason.featureDisabled ||
      result.reason == ContentAccessBlockReason.limitReached) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          result.reason == ContentAccessBlockReason.featureDisabled
              ? '${feature.label} indisponível'
              : 'Limite atingido',
        ),
        content: FreeLimitReachedView(
          feature: feature,
          limit: result.limit,
          used: result.used,
          showUpgradeButton: config.showUpgradeButton,
          showPadlock: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
