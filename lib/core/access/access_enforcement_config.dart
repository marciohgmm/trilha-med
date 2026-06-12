import '../../models/app_access_config_model.dart';

/// Rollout P0 — enforcement de limites do plano gratuito.
class AccessEnforcementConfig {
  const AccessEnforcementConfig({required this.enabled});

  final bool enabled;

  static AccessEnforcementConfig fromConfig(AppAccessConfigModel config) {
    return AccessEnforcementConfig(enabled: config.accessEnforcementEnabled);
  }
}
