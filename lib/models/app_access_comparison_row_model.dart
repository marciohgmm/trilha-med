/// Linha editável da comparação de planos (`display.comparisonRows`).
class AppAccessComparisonRowModel {
  const AppAccessComparisonRowModel({
    required this.featureId,
    this.freeText,
    this.premiumText,
  });

  final String featureId;
  final String? freeText;
  final String? premiumText;

  factory AppAccessComparisonRowModel.fromMap(Map<String, dynamic> data) {
    return AppAccessComparisonRowModel(
      featureId: data['featureId']?.toString() ?? '',
      freeText: _nonEmpty(data['freeText']),
      premiumText: _nonEmpty(data['premiumText']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featureId': featureId,
      if (freeText != null) 'freeText': freeText,
      if (premiumText != null) 'premiumText': premiumText,
    };
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final t = value.toString().trim();
    return t.isEmpty ? null : t;
  }
}
