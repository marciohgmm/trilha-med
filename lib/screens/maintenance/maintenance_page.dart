import 'package:flutter/material.dart';

import '../../core/feature_flags/feature_modules.dart';

/// Tela exibida quando um módulo está em manutenção remota.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({
    super.key,
    required this.moduleId,
    this.message,
  });

  final String moduleId;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final title = FeatureModules.label(moduleId);
    final body = (message ?? '').trim().isNotEmpty
        ? message!.trim()
        : 'Estamos realizando melhorias nesta área. '
            'Tente novamente em breve.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 72,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 24),
            Text(
              'Em manutenção',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Voltar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
