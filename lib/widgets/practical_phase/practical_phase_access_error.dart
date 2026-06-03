import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../screens/commercial/plans_page.dart';
import 'practical_phase_constants.dart';

/// Erros de acesso à Fase Prática (rules / paywall).
class PracticalPhaseAccessError {
  PracticalPhaseAccessError._();

  static bool isPermissionDenied(Object? error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final msg = error?.toString() ?? '';
    return msg.contains('permission-denied');
  }

  static Widget permissionDenied({
    required BuildContext context,
    String? userId,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: PracticalPhaseColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Conteúdo Premium',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: PracticalPhaseColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Este modelo é exclusivo para assinantes Premium. '
                'Assine ou regularize seu pagamento para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlansPage()),
                  );
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Ver planos'),
                style: FilledButton.styleFrom(
                  backgroundColor: PracticalPhaseColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
