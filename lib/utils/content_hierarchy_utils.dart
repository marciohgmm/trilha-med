import 'package:cloud_firestore/cloud_firestore.dart';

/// Hierarquia de conte?do: mat?ria ? subtema (sem n?vel tema).
class ContentHierarchyUtils {
  ContentHierarchyUtils._();

  /// Chave ?nica para agrupamento (cronograma, cache, etc.).
  static String subtemaPairKey(String materia, String subtema) {
    return '${materia.trim()}_${subtema.trim()}';
  }

  /// ID estável em `flashcards_materia_stats/{id}`.
  static String materiaCatalogDocId(String materia) {
    final slug = normalizeForSearch(materia)
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '');
    return slug.isEmpty ? 'materia' : slug;
  }

  /// ID estável em `flashcards_subtema_catalog/{id}`.
  static String subtemaCatalogDocId(String materia, String subtema) {
    final m = materiaCatalogDocId(materia);
    final s = materiaCatalogDocId(subtema);
    return '$m' '__' '$s';
  }

  /// Chave legada (mat?ria + tema + subtema) � leitura de dados antigos.
  static String legacyTripletKey(String materia, String tema, String subtema) {
    return '${materia.trim()}_${tema.trim()}_${subtema.trim()}';
  }

  static List<String> sortAlphabetically(Iterable<String> items) {
    final list =
        items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    list.sort((a, b) => _compareIgnoreCaseAndAccents(a, b));
    return list;
  }

  static int _compareIgnoreCaseAndAccents(String a, String b) {
    return normalizeForSearch(a).compareTo(normalizeForSearch(b));
  }

  static String normalizeForSearch(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('?', 'a')
        .replaceAll('?', 'a')
        .replaceAll('?', 'a')
        .replaceAll('?', 'a')
        .replaceAll('?', 'e')
        .replaceAll('?', 'e')
        .replaceAll('?', 'i')
        .replaceAll('?', 'o')
        .replaceAll('?', 'o')
        .replaceAll('?', 'o')
        .replaceAll('?', 'u')
        .replaceAll('?', 'c');
  }

  /// Correspond?ncia parcial (prefixo ou substring) ap?s normaliza??o.
  static bool matchesSubtemaQuery(String subtema, String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    if (q.length < 2) return false;
    final s = normalizeForSearch(subtema);
    return s.startsWith(q) || s.contains(q);
  }

  /// Extrai subtemas distintos de documentos Firestore, ordenados A�Z.
  static List<String> extractSubtemasFromDocs(
    List<QueryDocumentSnapshot> docs, {
    String? materia,
  }) {
    final set = <String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (materia != null &&
          (data['materia'] ?? '').toString().trim() != materia.trim()) {
        continue;
      }
      final subtema = (data['subtema'] ?? '').toString().trim();
      if (subtema.isNotEmpty) set.add(subtema);
    }
    return sortAlphabetically(set);
  }

  /// Contagem de cards por subtema (mat?ria opcional).
  static Map<String, int> countBySubtema(
    List<QueryDocumentSnapshot> docs, {
    String? materia,
  }) {
    final map = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (materia != null &&
          (data['materia'] ?? '').toString().trim() != materia.trim()) {
        continue;
      }
      final subtema = (data['subtema'] ?? '').toString().trim();
      if (subtema.isEmpty) continue;
      map[subtema] = (map[subtema] ?? 0) + 1;
    }
    return map;
  }

  /// Filtra subtemas por texto de busca (m?n. 2 caracteres).
  static List<String> filterSubtemas(List<String> subtemas, String query) {
    final q = query.trim();
    if (q.length < 2) return subtemas;
    return subtemas.where((s) => matchesSubtemaQuery(s, q)).toList();
  }
}
