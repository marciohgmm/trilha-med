import 'package:cloud_firestore/cloud_firestore.dart';

/// Par único matéria/subtema (`flashcards_subtema_catalog/{id}`).
class FlashcardSubtemaCatalogEntry {
  const FlashcardSubtemaCatalogEntry({
    required this.id,
    required this.materia,
    required this.subtema,
    required this.cardCount,
    this.updatedAt,
  });

  final String id;
  final String materia;
  final String subtema;
  final int cardCount;
  final DateTime? updatedAt;

  factory FlashcardSubtemaCatalogEntry.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    return FlashcardSubtemaCatalogEntry(
      id: id,
      materia: (data['materia'] ?? '').toString().trim(),
      subtema: (data['subtema'] ?? '').toString().trim(),
      cardCount: (data['cardCount'] as num?)?.toInt() ?? 0,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, String> toCronogramaPair() => {
        'materia': materia,
        'subtema': subtema,
      };
}
