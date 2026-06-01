import 'package:cloud_firestore/cloud_firestore.dart';

/// Par único matéria/subtema (`questoes_subtema_catalog/{id}`).
class QuestaoSubtemaCatalogEntry {
  const QuestaoSubtemaCatalogEntry({
    required this.id,
    required this.materia,
    required this.subtema,
    required this.questaoCount,
    this.updatedAt,
  });

  final String id;
  final String materia;
  final String subtema;
  final int questaoCount;
  final DateTime? updatedAt;

  factory QuestaoSubtemaCatalogEntry.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    return QuestaoSubtemaCatalogEntry(
      id: id,
      materia: (data['materia'] ?? '').toString().trim(),
      subtema: (data['subtema'] ?? '').toString().trim(),
      questaoCount: (data['questaoCount'] as num?)?.toInt() ?? 0,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
