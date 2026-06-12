import '../core/commercial/commercial_entitlement.dart';
import '../domain/platform/models/subscription_plan.dart';
import '../models/app_access_config_model.dart';
import 'commercial_plan_presentation.dart';

/// Catálogo estático do plano gratuito + benefícios padrão para comparação.
///
/// Preços reais vêm de `platform_subscription_plans` (Firestore / Painel Mestre).
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

  /// Extras além do gratuito (não repetir "Tudo do plano Gratuito" na tabela).
  static const defaultPremiumBenefits = [
    'Tudo do plano Gratuito',
    'Simulados premium (quando ativados)',
    'Fase prática completa',
    'Relatórios avançados de desempenho',
    'Prioridade em eventos ao vivo',
    'Suporte prioritário',
  ];

  /// Lista para cards — gratuito usa só benefícios free; premium usa merge.
  static List<String> benefitsForPlan(SubscriptionPlan? plan) {
    if (plan == null || plan.tier == PlanTier.free) {
      return CommercialPlanPresentation.freeCardBenefits();
    }
    return CommercialPlanPresentation.premiumCardBenefits(plan);
  }

  /// Tabela comparativa corrigida (Premium inclui benefícios do Gratuito).
  static List<PlanBenefitComparisonRow> comparisonForPremium(
    SubscriptionPlan? premiumPlan,
  ) {
    return CommercialPlanPresentation.buildComparisonRows(premiumPlan);
  }

  /// Preferência: config do admin; senão benefícios do plano no Firestore.
  static List<PlanBenefitComparisonRow> comparisonForDisplay({
    AppAccessConfigModel? accessConfig,
    SubscriptionPlan? premiumPlan,
  }) {
    if (accessConfig != null) {
      return CommercialPlanPresentation.buildComparisonFromAccessConfig(
        accessConfig,
      );
    }
    return comparisonForPremium(premiumPlan);
  }

  static PremiumPricingDisplay pricingFor(SubscriptionPlan plan) {
    return PremiumPricingDisplay.fromPlan(plan);
  }
}
