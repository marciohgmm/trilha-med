import '../../../core/audit/audit_log_entry.dart';

/// Métrica de conversão por vendedor ou afiliado.
class CommercialAttributionMetric {
  final String id;
  final String label;
  final int conversions;
  final double revenue;

  const CommercialAttributionMetric({
    required this.id,
    required this.label,
    this.conversions = 0,
    this.revenue = 0,
  });
}

/// Agregação para dashboard admin mestre (runtime; futuro: Cloud Function).
class AdminDashboardSnapshot {
  final int totalUsers;
  final int activeUsers;
  final int newUsersLast30Days;
  final int totalAdmins;
  final int totalSellers;
  final int totalAffiliates;
  final int totalSubscriptions;
  final double projectedRevenueMonthly;

  final int activeSubscriptions;
  final int trialingSubscriptions;
  final int expiredSubscriptions;
  final double revenueToday;
  final double revenueMonth;
  final int pendingPayments;
  final int activeCoupons;
  final int unreadAdminNotifications;
  final List<CommercialAttributionMetric> sellerConversions;
  final List<CommercialAttributionMetric> affiliateConversions;
  final List<AuditLogEntry> recentAuditEvents;
  final DateTime generatedAt;

  const AdminDashboardSnapshot({
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.newUsersLast30Days = 0,
    this.totalAdmins = 0,
    this.totalSellers = 0,
    this.totalAffiliates = 0,
    this.totalSubscriptions = 0,
    this.projectedRevenueMonthly = 0,
    this.activeSubscriptions = 0,
    this.trialingSubscriptions = 0,
    this.expiredSubscriptions = 0,
    this.revenueToday = 0,
    this.revenueMonth = 0,
    this.pendingPayments = 0,
    this.activeCoupons = 0,
    this.unreadAdminNotifications = 0,
    this.sellerConversions = const [],
    this.affiliateConversions = const [],
    this.recentAuditEvents = const [],
    required this.generatedAt,
  });

  factory AdminDashboardSnapshot.empty() =>
      AdminDashboardSnapshot(generatedAt: DateTime.now());
}
