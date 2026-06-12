import '../core/access/app_access_feature.dart';
import '../domain/platform/models/subscription_plan.dart';
import '../models/app_access_config_model.dart';
import '../models/app_access_plan_tier_model.dart';
import 'commercial_plan_catalog.dart';

/// Linha da tabela comparativa Gratuito vs Premium.
class PlanBenefitComparisonRow {
  final String benefit;
  final bool includedInFree;
  final bool includedInPremium;
  final String? freeText;
  final String? premiumText;

  const PlanBenefitComparisonRow({
    required this.benefit,
    required this.includedInFree,
    required this.includedInPremium,
    this.freeText,
    this.premiumText,
  });
}

/// Preços formatados para exibição na tela de planos.
class PremiumPricingDisplay {
  final double priceMonthly;
  final double priceYearly;
  final String currency;
  final bool hasMonthly;
  final bool hasYearly;
  final bool configured;

  const PremiumPricingDisplay({
    required this.priceMonthly,
    required this.priceYearly,
    this.currency = 'BRL',
    required this.hasMonthly,
    required this.hasYearly,
    required this.configured,
  });

  factory PremiumPricingDisplay.fromPlan(SubscriptionPlan plan) {
    final monthly = plan.priceMonthly;
    final yearly = plan.priceYearly;
    return PremiumPricingDisplay(
      priceMonthly: monthly,
      priceYearly: yearly,
      currency: plan.currency,
      hasMonthly: monthly > 0,
      hasYearly: yearly > 0,
      configured: monthly > 0 || yearly > 0,
    );
  }

  String formatMoney(double value) => CommercialPlanPresentation.formatBrl(value);

  String get primaryPriceLabel {
    if (hasMonthly) return '${formatMoney(priceMonthly)}/mês';
    if (hasYearly) return '${formatMoney(priceYearly)}/ano';
    return 'Preço sob consulta';
  }

  String? get secondaryPriceLabel {
    if (hasMonthly && hasYearly) {
      return 'ou ${formatMoney(priceYearly)}/ano';
    }
    return null;
  }

  String ctaLabel(String billingPeriod) {
    if (billingPeriod == 'yearly' && hasYearly) {
      return 'Assinar Premium — ${formatMoney(priceYearly)}/ano';
    }
    if (hasMonthly) {
      return 'Assinar Premium — ${formatMoney(priceMonthly)}/mês';
    }
    if (hasYearly) {
      return 'Assinar Premium — ${formatMoney(priceYearly)}/ano';
    }
    return 'Assinar Premium';
  }
}

/// Benefícios e comparação para UI de planos.
class CommercialPlanPresentation {
  CommercialPlanPresentation._();

  static String formatBrl(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Benefícios exibidos no card Premium (gratuito + extras, sem linha genérica).
  static List<String> premiumCardBenefits(SubscriptionPlan? premiumPlan) {
    final free = CommercialPlanCatalog.freePlan.benefitLabels;
    final extras = _premiumExclusiveBenefits(premiumPlan);
    return [...free, ...extras];
  }

  /// Benefícios só do gratuito (card Gratuito).
  static List<String> freeCardBenefits() {
    return List<String>.from(CommercialPlanCatalog.freePlan.benefitLabels);
  }

  /// Tabela espelhando o Painel Mestre → Gratuito vs Premium (`app_access_config`).
  static List<PlanBenefitComparisonRow> buildComparisonFromAccessConfig(
    AppAccessConfigModel config,
  ) {
    return [
      for (final f in AppAccessFeature.adminFeatures)
        _rowForFeature(config, f),
    ];
  }

  static PlanBenefitComparisonRow _rowForFeature(
    AppAccessConfigModel config,
    AppAccessFeature feature,
  ) {
    final override = config.comparisonOverrideFor(feature.id);
    final inFree = config.free.isFeatureEnabled(feature);
    final inPremium = _premiumShowsInComparison(config, feature);
    return PlanBenefitComparisonRow(
      benefit: feature.label,
      includedInFree: inFree,
      includedInPremium: inPremium,
      freeText: override?.freeText ?? _defaultFreeCellText(config.free, feature),
      premiumText:
          override?.premiumText ?? _defaultPremiumCellText(config.premium, feature, inPremium),
    );
  }

  static String _defaultFreeCellText(
    AppAccessPlanTierModel tier,
    AppAccessFeature feature,
  ) {
    if (!tier.isFeatureEnabled(feature)) return 'Não incluído';
    if (!tier.isFeatureAvailable(feature, isPremiumTier: false)) {
      return 'Indisponível';
    }
    final limit = tier.limitFor(feature);
    if (limit != null && limit > 0) return 'Até $limit';
    return 'Incluído';
  }

  static String _defaultPremiumCellText(
    AppAccessPlanTierModel tier,
    AppAccessFeature feature,
    bool includedInPremium,
  ) {
    if (!includedInPremium) return 'Não incluído';
    if (tier.hasUnlimited(feature, isPremiumTier: true)) return 'Ilimitado';
    final limit = tier.limitFor(feature);
    if (limit != null && limit > 0) return 'Até $limit';
    return 'Incluído';
  }

  static bool _premiumShowsInComparison(
    AppAccessConfigModel config,
    AppAccessFeature feature,
  ) {
    final inFree = config.free.isFeatureEnabled(feature);
    final inPremium = config.premium.isFeatureEnabled(feature);
    if (inPremium) return true;
    if (!inFree) return false;
    return false;
  }

  /// Tabela: Premium marca ✓ em tudo que o Gratuito tem + extras exclusivos.
  static List<PlanBenefitComparisonRow> buildComparisonRows(
    SubscriptionPlan? premiumPlan,
  ) {
    final free = CommercialPlanCatalog.freePlan.benefitLabels;
    final extras = _premiumExclusiveBenefits(premiumPlan);
    final rows = <PlanBenefitComparisonRow>[];

    for (final benefit in free) {
      rows.add(
        PlanBenefitComparisonRow(
          benefit: benefit,
          includedInFree: true,
          includedInPremium: true,
          freeText: 'Incluído',
          premiumText: 'Incluído',
        ),
      );
    }

    for (final benefit in extras) {
      if (free.contains(benefit)) continue;
      rows.add(
        PlanBenefitComparisonRow(
          benefit: benefit,
          includedInFree: false,
          includedInPremium: true,
          freeText: 'Não incluído',
          premiumText: 'Incluído',
        ),
      );
    }

    return rows;
  }

  static List<String> _premiumExclusiveBenefits(SubscriptionPlan? premiumPlan) {
    final raw = premiumPlan != null && premiumPlan.benefitLabels.isNotEmpty
        ? premiumPlan.benefitLabels
        : CommercialPlanCatalog.defaultPremiumBenefits;

    return raw
        .where((b) => !_isGenericFreeIncludeLine(b))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  static bool _isGenericFreeIncludeLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('tudo do plano gratuito') ||
        lower.contains('tudo do gratuito') ||
        lower == 'tudo do plano gratuito';
  }
}
