/// Entrada do histórico local de calculadoras.
class MedicalToolHistoryEntry {
  const MedicalToolHistoryEntry({
    required this.id,
    required this.toolId,
    required this.title,
    required this.summary,
    required this.calculatedAt,
  });

  final String id;
  final String toolId;
  final String title;
  final String summary;
  final DateTime calculatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolId': toolId,
        'title': title,
        'summary': summary,
        'calculatedAt': calculatedAt.toIso8601String(),
      };

  factory MedicalToolHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MedicalToolHistoryEntry(
      id: json['id'] as String,
      toolId: json['toolId'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }
}
