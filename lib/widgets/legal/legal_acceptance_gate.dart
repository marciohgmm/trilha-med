import 'package:flutter/material.dart';

import '../../screens/legal/legal_acceptance_required_page.dart';
import '../../services/legal/legal_acceptance_service.dart';

/// Bloqueia o app até aceite das versões vigentes de política e termos.
class LegalAcceptanceGate extends StatelessWidget {
  const LegalAcceptanceGate({
    super.key,
    required this.userId,
    required this.child,
  });

  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: LegalAcceptanceService().watchNeedsAcceptance(userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final needs = snap.data ?? true;
        if (needs) {
          return LegalAcceptanceRequiredPage(userId: userId);
        }
        return child;
      },
    );
  }
}
