/// Chaves de entitlement comercial — fonte de verdade do paywall.
enum CommercialEntitlementKey {
  premium('premium', 'Premium'),
  premiumLifetime('premium_lifetime', 'Premium vitalício'),
  courtesyAccess('courtesy_access', 'Cortesia'),
  betaTester('beta_tester', 'Beta tester'),
  sellerAccess('seller_access', 'Acesso vendedor'),
  affiliateAccess('affiliate_access', 'Acesso afiliado');

  final String key;
  final String label;

  const CommercialEntitlementKey(this.key, this.label);

  static CommercialEntitlementKey? fromKey(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final e in CommercialEntitlementKey.values) {
      if (e.key == value) return e;
    }
    return null;
  }

  /// Entitlements que liberam conteúdo premium pago.
  static const premiumAccessKeys = [
    CommercialEntitlementKey.premium,
    CommercialEntitlementKey.premiumLifetime,
    CommercialEntitlementKey.courtesyAccess,
    CommercialEntitlementKey.betaTester,
  ];
}

/// Status exibido na tela "Minha Assinatura".
enum SubscriptionDisplayStatus {
  free('free', 'Gratuito'),
  active('active', 'Ativo'),
  expired('expired', 'Expirado'),
  lifetime('lifetime', 'Vitalício'),
  courtesy('courtesy', 'Cortesia'),
  beta('beta', 'Beta tester');

  final String key;
  final String label;

  const SubscriptionDisplayStatus(this.key, this.label);
}

/// Origem de concessão manual (Painel Mestre).
enum CommercialGrantSource {
  manual('manual', 'Manual'),
  courtesy('courtesy', 'Cortesia'),
  lifetime('lifetime', 'Vitalício'),
  promotional('promotional', 'Promocional'),
  lottery('lottery', 'Sorteio'),
  beta('beta', 'Beta tester'),
  mercadoPago('mercado_pago', 'Mercado Pago');

  final String key;
  final String label;

  const CommercialGrantSource(this.key, this.label);

  static CommercialGrantSource fromKey(String? value) {
    for (final e in CommercialGrantSource.values) {
      if (e.key == value) return e;
    }
    return CommercialGrantSource.manual;
  }
}

/// Tier de plano para comparação pública.
enum PlanTier {
  free('free', 'Gratuito'),
  premium('premium', 'Premium');

  final String key;
  final String label;

  const PlanTier(this.key, this.label);

  static PlanTier fromKey(String? value) {
    for (final e in PlanTier.values) {
      if (e.key == value) return e;
    }
    return PlanTier.free;
  }
}
