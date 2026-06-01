import 'package:cloud_firestore/cloud_firestore.dart';

/// Flag remota de módulo (`platform_feature_flags/{moduleId}`).
class FeatureFlagModel {
  const FeatureFlagModel({
    required this.id,
    required this.enabled,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final bool enabled;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory FeatureFlagModel.enabledDefault(String id) {
    return FeatureFlagModel(
      id: id,
      enabled: true,
      maintenanceMode: false,
      maintenanceMessage: '',
    );
  }

  factory FeatureFlagModel.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return FeatureFlagModel(
      id: id,
      enabled: data['enabled'] as bool? ?? true,
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: (data['maintenanceMessage'] as String? ?? '').trim(),
      updatedAt: _readTimestamp(data['updatedAt']),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({String? updatedBy}) {
    return {
      'enabled': enabled,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  FeatureFlagModel copyWith({
    bool? enabled,
    bool? maintenanceMode,
    String? maintenanceMessage,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return FeatureFlagModel(
      id: id,
      enabled: enabled ?? this.enabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  bool get isAccessible => enabled && !maintenanceMode;

  static DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
