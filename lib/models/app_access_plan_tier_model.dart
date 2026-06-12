import '../core/access/app_access_feature.dart';

/// Regras de um tier (`free` ou `premium`) em `app_access_config/plans`.
class AppAccessPlanTierModel {
  final Map<String, bool> enabledByField;
  final Map<String, int> limitsByField;

  const AppAccessPlanTierModel({
    this.enabledByField = const {},
    this.limitsByField = const {},
  });

  bool isFeatureEnabled(AppAccessFeature feature) {
    return enabledByField[feature.enabledField] ?? false;
  }

  /// No tier **gratuito**, `0` = recurso desabilitado (P0).
  /// No tier **premium**, `0` ou ausente = ilimitado para features com limite.
  int? limitFor(AppAccessFeature feature) {
    final field = feature.limitField;
    if (field == null) return null;
    if (!limitsByField.containsKey(field)) return null;
    return limitsByField[field];
  }

  bool hasUnlimited(AppAccessFeature feature, {required bool isPremiumTier}) {
    if (!isPremiumTier) return false;
    final limit = limitFor(feature);
    return limit == null || limit <= 0;
  }

  /// Feature disponível para o tier (enabled + limite válido no free).
  bool isFeatureAvailable(AppAccessFeature feature, {required bool isPremiumTier}) {
    if (!isFeatureEnabled(feature)) return false;
    if (isPremiumTier) return true;
    final limitField = feature.limitField;
    if (limitField == null) return true;
    final limit = limitFor(feature);
    if (limit == null) return true;
    return limit > 0;
  }

  AppAccessPlanTierModel copyWith({
    Map<String, bool>? enabledByField,
    Map<String, int>? limitsByField,
  }) {
    return AppAccessPlanTierModel(
      enabledByField: enabledByField ?? this.enabledByField,
      limitsByField: limitsByField ?? this.limitsByField,
    );
  }

  AppAccessPlanTierModel setFeatureEnabled(
    AppAccessFeature feature,
    bool enabled,
  ) {
    return copyWith(
      enabledByField: {...enabledByField, feature.enabledField: enabled},
    );
  }

  AppAccessPlanTierModel setFeatureLimit(
    AppAccessFeature feature,
    int limit,
  ) {
    final field = feature.limitField;
    if (field == null) return this;
    return copyWith(
      limitsByField: {...limitsByField, field: limit},
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    for (final e in enabledByField.entries) {
      map[e.key] = e.value;
    }
    for (final e in limitsByField.entries) {
      map[e.key] = e.value;
    }
    return map;
  }

  factory AppAccessPlanTierModel.fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const AppAccessPlanTierModel();
    }
    final enabled = <String, bool>{};
    final limits = <String, int>{};
    for (final feature in AppAccessFeature.values) {
      final enabledKey = feature.enabledField;
      if (raw.containsKey(enabledKey)) {
        enabled[enabledKey] = raw[enabledKey] == true;
      }
      final limitKey = feature.limitField;
      if (limitKey != null && raw.containsKey(limitKey)) {
        limits[limitKey] = _readInt(raw[limitKey]);
      }
    }
    return AppAccessPlanTierModel(
      enabledByField: enabled,
      limitsByField: limits,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
