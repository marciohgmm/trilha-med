import 'package:flutter/material.dart';

import '../../models/feature_flag_model.dart';
import '../../screens/maintenance/maintenance_page.dart';
import '../../services/feature_flags/feature_flag_service.dart';

/// Controla visibilidade e manutenção de módulos via `platform_feature_flags`.
class FeatureGate extends StatelessWidget {
  const FeatureGate({
    super.key,
    required this.moduleId,
    required this.onEnabled,
    required this.childBuilder,
    this.hideWhenDisabled = true,
    this.loadingChild,
    this.disabledChild,
  });

  final String moduleId;
  final VoidCallback onEnabled;

  /// Recebe `onPressed` pronto (null = desabilitado).
  final Widget Function(VoidCallback? onPressed) childBuilder;

  final bool hideWhenDisabled;
  final Widget? loadingChild;
  final Widget? disabledChild;

  static void openMaintenance(
    BuildContext context, {
    required String moduleId,
    String? message,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaintenancePage(
          moduleId: moduleId,
          message: message,
        ),
      ),
    );
  }

  static VoidCallback? resolveOnPressed({
    required BuildContext context,
    required FeatureFlagModel flag,
    required VoidCallback onEnabled,
  }) {
    if (!flag.enabled) return null;
    if (flag.maintenanceMode) {
      return () => openMaintenance(
            context,
            moduleId: flag.id,
            message: flag.maintenanceMessage,
          );
    }
    return onEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, FeatureFlagModel>>(
      stream: FeatureFlagService.instance.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loadingChild ?? childBuilder(onEnabled);
        }

        final flag = snapshot.data?[moduleId] ??
            FeatureFlagModel.enabledDefault(moduleId);

        if (!flag.enabled) {
          if (hideWhenDisabled) return const SizedBox.shrink();
          return disabledChild ??
              Opacity(
                opacity: 0.45,
                child: AbsorbPointer(
                  child: childBuilder(null),
                ),
              );
        }

        final onPressed = resolveOnPressed(
          context: context,
          flag: flag,
          onEnabled: onEnabled,
        );
        return childBuilder(onPressed);
      },
    );
  }
}

/// Envolve um widget filho (ex.: seção) — oculta se desativado.
class FeatureGateSection extends StatelessWidget {
  const FeatureGateSection({
    super.key,
    required this.moduleId,
    required this.child,
    this.hideWhenDisabled = true,
  });

  final String moduleId;
  final Widget child;
  final bool hideWhenDisabled;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, FeatureFlagModel>>(
      stream: FeatureFlagService.instance.watchAll(),
      builder: (context, snapshot) {
        final flag = snapshot.data?[moduleId] ??
            FeatureFlagModel.enabledDefault(moduleId);
        if (!flag.enabled && hideWhenDisabled) {
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
