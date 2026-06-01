/// Snapshot agregado para dashboard de analytics (Painel Mestre).
class AnalyticsDashboardSnapshot {
  final int signUpsLast7Days;
  final int signUpsLast30Days;
  final int loginsLast7Days;
  final int sessionsLast7Days;
  final int dailyActiveUsersToday;
  final int dailyActiveUsersYesterday;

  final double retentionD1;
  final double retentionD7;
  final double retentionD30;
  final int cohortSizeForRetention;

  final int paywallViewsLast30Days;
  final int checkoutStartsLast30Days;
  final int purchasesApprovedLast30Days;
  final int purchasesCancelledLast30Days;
  final double checkoutConversionRate;

  final Map<String, int> featureUsageLast30Days;
  final Map<String, int> couponUsageLast30Days;
  final Map<String, int> affiliateConversionsLast30Days;
  final Map<String, int> sellerConversionsLast30Days;

  /// Receita espelhada (BRL) nos últimos 30 dias.
  final double revenueLast30Days;

  final DateTime generatedAt;

  const AnalyticsDashboardSnapshot({
    this.signUpsLast7Days = 0,
    this.signUpsLast30Days = 0,
    this.loginsLast7Days = 0,
    this.sessionsLast7Days = 0,
    this.dailyActiveUsersToday = 0,
    this.dailyActiveUsersYesterday = 0,
    this.retentionD1 = 0,
    this.retentionD7 = 0,
    this.retentionD30 = 0,
    this.cohortSizeForRetention = 0,
    this.paywallViewsLast30Days = 0,
    this.checkoutStartsLast30Days = 0,
    this.purchasesApprovedLast30Days = 0,
    this.purchasesCancelledLast30Days = 0,
    this.checkoutConversionRate = 0,
    this.featureUsageLast30Days = const {},
    this.couponUsageLast30Days = const {},
    this.affiliateConversionsLast30Days = const {},
    this.sellerConversionsLast30Days = const {},
    this.revenueLast30Days = 0,
    required this.generatedAt,
  });

  factory AnalyticsDashboardSnapshot.empty() =>
      AnalyticsDashboardSnapshot(generatedAt: DateTime.now());
}
