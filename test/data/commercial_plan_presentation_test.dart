import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/commercial/commercial_entitlement.dart';
import 'package:flutter_application_1/data/commercial_plan_catalog.dart';
import 'package:flutter_application_1/data/commercial_plan_presentation.dart';
import 'package:flutter_application_1/domain/platform/models/subscription_plan.dart';

void main() {
  test('Premium na tabela inclui benefícios do Gratuito', () {
    final premium = SubscriptionPlan(
      id: 'premium_test',
      name: 'Premium',
      tier: PlanTier.premium,
      benefitLabels: CommercialPlanCatalog.defaultPremiumBenefits,
      priceMonthly: 49.9,
    );

    final rows = CommercialPlanCatalog.comparisonForPremium(premium);
    final freeBenefits = CommercialPlanCatalog.freePlan.benefitLabels;

    for (final freeB in freeBenefits) {
      final row = rows.firstWhere((r) => r.benefit == freeB);
      expect(row.includedInFree, isTrue);
      expect(row.includedInPremium, isTrue, reason: freeB);
    }

    final fasePratica = rows.firstWhere(
      (r) => r.benefit.contains('Fase prática'),
    );
    expect(fasePratica.includedInFree, isFalse);
    expect(fasePratica.includedInPremium, isTrue);
  });

  test('card Premium lista gratuito + extras', () {
    final benefits = CommercialPlanPresentation.premiumCardBenefits(
      SubscriptionPlan(
        id: 'p',
        name: 'Premium',
        tier: PlanTier.premium,
        benefitLabels: CommercialPlanCatalog.defaultPremiumBenefits,
      ),
    );

    expect(benefits, contains('Flashcards por matéria'));
    expect(benefits, contains('Fase prática completa'));
    expect(benefits, isNot(contains('Tudo do plano Gratuito')));
  });

  test('PremiumPricingDisplay formata CTA', () {
    final pricing = PremiumPricingDisplay.fromPlan(
      SubscriptionPlan(
        id: 'p',
        name: 'Premium',
        priceMonthly: 39.9,
        priceYearly: 399,
        tier: PlanTier.premium,
      ),
    );
    expect(pricing.ctaLabel('monthly'), contains('39,90'));
    expect(pricing.ctaLabel('monthly'), contains('/mês'));
  });
}
