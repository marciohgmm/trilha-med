import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_access_comparison_row_model.dart';
import 'app_access_plan_tier_model.dart';

/// Documento `app_access_config/plans` — gratuito vs premium + UI de bloqueio.
class AppAccessConfigModel {
  const AppAccessConfigModel({
    required this.free,
    required this.premium,
    this.schemaVersion = 0,
    this.showLockedWithPadlock = true,
    this.showUpgradeButton = true,
    this.accessEnforcementEnabled = false,
    this.comparisonRows = const [],
    this.updatedAt,
    this.updatedBy,
  });

  static const String documentId = 'plans';

  final AppAccessPlanTierModel free;
  final AppAccessPlanTierModel premium;
  final int schemaVersion;
  final bool showLockedWithPadlock;
  final bool showUpgradeButton;
  final bool accessEnforcementEnabled;
  final List<AppAccessComparisonRowModel> comparisonRows;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory AppAccessConfigModel.fromDoc(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return AppAccessConfigModel.empty();
    }
    final display = data['display'] as Map<String, dynamic>?;
    final rowsRaw = display?['comparisonRows'];
    final rows = <AppAccessComparisonRowModel>[];
    if (rowsRaw is List) {
      for (final item in rowsRaw) {
        if (item is Map<String, dynamic>) {
          rows.add(AppAccessComparisonRowModel.fromMap(item));
        } else if (item is Map) {
          rows.add(AppAccessComparisonRowModel.fromMap(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }
    return AppAccessConfigModel(
      schemaVersion: _readInt(data['schemaVersion']),
      free: AppAccessPlanTierModel.fromMap(
        data['free'] as Map<String, dynamic>?,
      ),
      premium: AppAccessPlanTierModel.fromMap(
        data['premium'] as Map<String, dynamic>?,
      ),
      showLockedWithPadlock: display?['showLockedWithPadlock'] != false,
      showUpgradeButton: display?['showUpgradeButton'] != false,
      accessEnforcementEnabled: display?['accessEnforcementEnabled'] == true,
      comparisonRows: rows,
      updatedAt: _readDate(data['updatedAt']),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  factory AppAccessConfigModel.empty() {
    return AppAccessConfigModel(
      free: const AppAccessPlanTierModel(),
      premium: const AppAccessPlanTierModel(),
    );
  }

  Map<String, dynamic> toFirestore({required String updatedBy}) {
    return {
      if (schemaVersion > 0) 'schemaVersion': schemaVersion,
      'free': free.toMap(),
      'premium': premium.toMap(),
      'display': {
        'showLockedWithPadlock': showLockedWithPadlock,
        'showUpgradeButton': showUpgradeButton,
        'accessEnforcementEnabled': accessEnforcementEnabled,
        if (comparisonRows.isNotEmpty)
          'comparisonRows': comparisonRows.map((e) => e.toMap()).toList(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  AppAccessConfigModel copyWith({
    AppAccessPlanTierModel? free,
    AppAccessPlanTierModel? premium,
    int? schemaVersion,
    bool? showLockedWithPadlock,
    bool? showUpgradeButton,
    bool? accessEnforcementEnabled,
    List<AppAccessComparisonRowModel>? comparisonRows,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AppAccessConfigModel(
      free: free ?? this.free,
      premium: premium ?? this.premium,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      showLockedWithPadlock:
          showLockedWithPadlock ?? this.showLockedWithPadlock,
      showUpgradeButton: showUpgradeButton ?? this.showUpgradeButton,
      accessEnforcementEnabled:
          accessEnforcementEnabled ?? this.accessEnforcementEnabled,
      comparisonRows: comparisonRows ?? this.comparisonRows,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  AppAccessComparisonRowModel? comparisonOverrideFor(String featureId) {
    for (final row in comparisonRows) {
      if (row.featureId == featureId) return row;
    }
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
