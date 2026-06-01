import 'package:flutter/material.dart';

import '../../core/commercial/commercial_entitlement.dart';
import '../../screens/commercial/plans_page.dart';
import '../commercial/paywall_gate.dart';
import 'practical_phase_constants.dart';

/// Paywall da Fase Prática — usa [CommercialAccessService] via [PaywallGate].
class PracticalPhasePremiumGate extends StatelessWidget {
  const PracticalPhasePremiumGate({
    super.key,
    required this.userId,
    required this.child,
    this.screenName = 'practical_phase_content',
  });

  final String userId;
  final Widget child;
  final String screenName;

  @override
  Widget build(BuildContext context) {
    return PaywallGate(
      userId: userId,
      requiredEntitlement: CommercialEntitlementKey.premium,
      screenName: screenName,
      fallback: PracticalPhasePremiumPrompt(
        onViewPlans: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlansPage()),
          );
        },
      ),
      child: child,
    );
  }
}

/// Tela de assinatura exibida ao tentar abrir conteúdo premium da Fase Prática.
class PracticalPhasePremiumPrompt extends StatelessWidget {
  const PracticalPhasePremiumPrompt({
    super.key,
    required this.onViewPlans,
  });

  final VoidCallback onViewPlans;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PracticalPhaseColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 56,
                  color: PracticalPhaseColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Fase Prática Premium',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: PracticalPhaseColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Você pode explorar a biblioteca de módulos e estações. '
                'Para abrir roteiros, materiais e checklists de cada modelo, '
                'assine o Premium.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onViewPlans,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Ver planos e assinar'),
                style: FilledButton.styleFrom(
                  backgroundColor: PracticalPhaseColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Flashcards, questões, cronograma, OSCE e eventos ao vivo '
                'continuam no plano gratuito.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
