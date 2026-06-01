/// Tipos de evento para trilha de auditoria.
enum AuditEventType {
  userLogin('user.login'),
  userRegister('user.register'),
  subscriptionCreated('subscription.created'),
  subscriptionCanceled('subscription.canceled'),
  paymentSucceeded('payment.succeeded'),
  paymentFailed('payment.failed'),
  paymentRefunded('payment.refunded'),
  couponApplied('coupon.applied'),
  couponCreated('coupon.created'),
  sellerCommission('seller.commission'),
  affiliateConversion('affiliate.conversion'),
  partnershipActivated('partnership.activated'),
  adImpression('ad.impression'),
  adClick('ad.click'),
  adminAction('admin.action'),
  permissionChanged('permission.changed'),
  accessGranted('access.granted'),
  accessDenied('access.denied'),
  featureFlagUpdated('feature_flag.updated');

  final String key;
  const AuditEventType(this.key);

  static AuditEventType? fromKey(String? key) {
    if (key == null) return null;
    for (final e in AuditEventType.values) {
      if (e.key == key) return e;
    }
    return null;
  }
}
