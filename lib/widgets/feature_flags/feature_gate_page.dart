import 'package:flutter/material.dart';

import '../../models/feature_flag_model.dart';
import '../../screens/maintenance/maintenance_page.dart';
import '../../services/feature_flags/feature_flag_service.dart';

/// Envolve uma tela inteira — bloqueia ou exibe manutenção.
class FeatureGatePage extends StatelessWidget {
  const FeatureGatePage({
    super.key,
    required this.moduleId,
    required this.builder,
    this.unavailableTitle,
  });

  final String moduleId;
  final Widget Function(BuildContext context) builder;
  final String? unavailableTitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, FeatureFlagModel>>(
      stream: FeatureFlagService.instance.watchAll(),
      builder: (context, snapshot) {
        final flag = snapshot.data?[moduleId] ??
            FeatureFlagModel.enabledDefault(moduleId);

        if (!flag.enabled) {
          return Scaffold(
            appBar: AppBar(
              title: Text(unavailableTitle ?? 'Indisponível'),
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este módulo está temporariamente indisponível.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (flag.maintenanceMode) {
          return MaintenancePage(
            moduleId: moduleId,
            message: flag.maintenanceMessage,
          );
        }

        return builder(context);
      },
    );
  }
}
