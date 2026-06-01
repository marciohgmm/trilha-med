enum SubscriptionStatus {
  trialing('trialing'),
  active('active'),
  pastDue('past_due'),
  canceled('canceled'),
  expired('expired');

  final String key;
  const SubscriptionStatus(this.key);

  static SubscriptionStatus fromKey(String? v) {
    for (final e in SubscriptionStatus.values) {
      if (e.key == v) return e;
    }
    return SubscriptionStatus.expired;
  }
}

enum PaymentStatus {
  pending('pending'),
  processing('processing'),
  succeeded('succeeded'),
  failed('failed'),
  refunded('refunded'),
  canceled('canceled');

  final String key;
  const PaymentStatus(this.key);

  static PaymentStatus fromKey(String? v) {
    for (final e in PaymentStatus.values) {
      if (e.key == v) return e;
    }
    return PaymentStatus.pending;
  }
}

enum PaymentProvider {
  manual('manual'),
  stripe('stripe'),
  mercadoPago('mercado_pago'),
  apple('apple'),
  google('google');

  final String key;
  const PaymentProvider(this.key);

  static PaymentProvider fromKey(String? v) {
    for (final e in PaymentProvider.values) {
      if (e.key == v) return e;
    }
    return PaymentProvider.manual;
  }
}

enum CouponDiscountType {
  percent('percent'),
  fixed('fixed');

  final String key;
  const CouponDiscountType(this.key);

  static CouponDiscountType fromKey(String? v) {
    for (final e in CouponDiscountType.values) {
      if (e.key == v) return e;
    }
    return CouponDiscountType.percent;
  }
}

enum AdvertisementPlacement {
  homeBanner('home_banner'),
  studyInterstitial('study_interstitial'),
  osceLobby('osce_lobby'),
  practicalPhase('practical_phase');

  final String key;
  const AdvertisementPlacement(this.key);

  static AdvertisementPlacement fromKey(String? v) {
    for (final e in AdvertisementPlacement.values) {
      if (e.key == v) return e;
    }
    return AdvertisementPlacement.homeBanner;
  }
}

enum NotificationChannel {
  inApp('in_app'),
  email('email'),
  push('push');

  final String key;
  const NotificationChannel(this.key);

  static NotificationChannel fromKey(String? v) {
    for (final e in NotificationChannel.values) {
      if (e.key == v) return e;
    }
    return NotificationChannel.inApp;
  }
}

enum PartnershipStatus {
  draft('draft'),
  active('active'),
  paused('paused'),
  ended('ended');

  final String key;
  const PartnershipStatus(this.key);

  static PartnershipStatus fromKey(String? v) {
    for (final e in PartnershipStatus.values) {
      if (e.key == v) return e;
    }
    return PartnershipStatus.draft;
  }
}
