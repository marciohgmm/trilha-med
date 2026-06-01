import 'package:cloud_firestore/cloud_firestore.dart';

/// Contagem agregada de flashcards por matéria (`flashcards_materia_stats/{id}`).
class FlashcardMateriaStat {
  const FlashcardMateriaStat({
    required this.id,
    required this.name,
    required this.total,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int total;
  final DateTime? updatedAt;

  factory FlashcardMateriaStat.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    return FlashcardMateriaStat(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Linha da Home: totais do catálogo + progresso do usuário.
class MateriaHomeProgress {
  const MateriaHomeProgress({
    required this.materia,
    required this.total,
    required this.estudados,
  });

  final String materia;
  final int total;
  final int estudados;

  double get progresso => total > 0 ? estudados / total : 0.0;
}
