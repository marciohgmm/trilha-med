import '../../core/commercial/commercial_entitlement.dart';
import '../../domain/platform/models/subscription_plan.dart';

/// Catálogo estático do plano gratuito + benefícios padrão para comparação.
class CommercialPlanCatalog {
  CommercialPlanCatalog._();

  static const freePlanId = 'free';

  static SubscriptionPlan get freePlan => const SubscriptionPlan(
        id: freePlanId,
        name: 'Gratuito',
        description: 'Estudo com flashcards, questões e recursos essenciais.',
        priceMonthly: 0,
        priceYearly: 0,
        tier: PlanTier.free,
        isActive: true,
        sortOrder: 0,
        benefitLabels: [
          'Flashcards por matéria',
          'Questões por tema',
          'Cronograma de estudos',
          'OSCE multiplayer (básico)',
          'Eventos ao vivo abertos',
        ],
      );

  static const defaultPremiumBenefits = [
    'Tudo do plano Gratuito',
    'Simulados premium (quando ativados)',
    'Fase prática completa',
    'Relatórios avançados de desempenho',
    'Prioridade em eventos ao vivo',
    'Suporte prioritário',
  ];

  static List<String> benefitsForPlan(SubscriptionPlan? plan) {
    if (plan == null || plan.tier == PlanTier.free) {
      return freePlan.benefitLabels;
    }
    if (plan.benefitLabels.isNotEmpty) return plan.benefitLabels;
    return defaultPremiumBenefits;
  }
}
