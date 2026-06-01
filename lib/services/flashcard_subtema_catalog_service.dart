import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../models/flashcard_subtema_catalog_entry.dart';
import '../utils/content_hierarchy_utils.dart';

/// Catálogo de pares matéria/subtema — evita `flashcards.get()` no cronograma.
class FlashcardSubtemaCatalogService {
  FlashcardSubtemaCatalogService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final FlashcardSubtemaCatalogService instance =
      FlashcardSubtemaCatalogService();

  final FirebaseFirestore _db;

  static const _pageSize = 400;
  static const _cacheTtl = Duration(minutes: 5);

  List<Map<String, String>>? _cachedPairs;
  DateTime? _cachedAt;

  CollectionReference<Map<String, dynamic>> get _catalogCol =>
      _db.collection(FirestorePaths.flashcardsSubtemaCatalog);

  /// Pares para cronograma (matéria + subtema), com cache em memória por execução.
  Future<List<Map<String, String>>> fetchAllPairsForCronograma({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedPairs != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return List<Map<String, String>>.from(_cachedPairs!);
    }

    await ensureSeededIfEmpty();

    final snap = await _catalogCol.get();
    final pairs = snap.docs
        .map((d) => FlashcardSubtemaCatalogEntry.fromDoc(d.id, d.data()))
        .where((e) => e.materia.isNotEmpty && e.subtema.isNotEmpty && e.cardCount > 0)
        .map((e) => e.toCronogramaPair())
        .toList();

    _cachedPairs = pairs;
    _cachedAt = now;
    return List<Map<String, String>>.from(pairs);
  }

  void invalidateCache() {
    _cachedPairs = null;
    _cachedAt = null;
  }

  Stream<List<FlashcardSubtemaCatalogEntry>> watchByMateria(String materia) {
    final m = materia.trim();
    return _catalogCol
        .where('materia', isEqualTo: m)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FlashcardSubtemaCatalogEntry.fromDoc(d.id, d.data()))
            .where((e) =>
                e.materia.isNotEmpty &&
                e.subtema.isNotEmpty &&
                e.cardCount > 0)
            .toList());
  }

  Future<List<String>> fetchSubtemasByMateria(String materia) async {
    await ensureSeededIfEmpty();
    final snap =
        await _catalogCol.where('materia', isEqualTo: materia.trim()).get();
    return ContentHierarchyUtils.sortAlphabetically(
      snap.docs
          .map((d) => FlashcardSubtemaCatalogEntry.fromDoc(d.id, d.data()))
          .where((e) => e.subtema.isNotEmpty && e.cardCount > 0)
          .map((e) => e.subtema),
    );
  }

  Future<void> ensureSeededIfEmpty() async {
    try {
      final probe = await _catalogCol.limit(1).get();
      if (probe.docs.isNotEmpty) return;
      await rebuildFromFlashcards();
    } catch (e, st) {
      debugPrint('[FlashcardSubtemaCatalogService] ensureSeededIfEmpty: $e\n$st');
    }
  }

  Future<void> registerCard(String materia, String subtema) async {
    final m = materia.trim();
    final s = subtema.trim();
    if (m.isEmpty || s.isEmpty) return;

    final ref = _catalogCol.doc(ContentHierarchyUtils.subtemaCatalogDocId(m, s));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'cardCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'materia': m,
          'subtema': s,
          'cardCount': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    invalidateCache();
  }

  Future<void> unregisterCard(String materia, String subtema, {int by = 1}) async {
    final m = materia.trim();
    final s = subtema.trim();
    if (m.isEmpty || s.isEmpty || by <= 0) return;

    final ref = _catalogCol.doc(ContentHierarchyUtils.subtemaCatalogDocId(m, s));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['cardCount'] as num?)?.toInt() ?? 0;
      final next = current - by;
      if (next <= 0) {
        tx.delete(ref);
      } else {
        tx.update(ref, {
          'cardCount': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    invalidateCache();
  }

  /// Reconstrói catálogo paginado (seed / importação em massa).
  Future<void> rebuildFromFlashcards() async {
    final counts = <String, ({String materia, String subtema, int count})>{};

    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q = _db
          .collection(FirestorePaths.flashcards)
          .orderBy(FieldPath.documentId)
          .limit(_pageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final m = (doc.data()['materia'] ?? '').toString().trim();
        final s = (doc.data()['subtema'] ?? '').toString().trim();
        if (m.isEmpty || s.isEmpty) continue;
        final id = ContentHierarchyUtils.subtemaCatalogDocId(m, s);
        final prev = counts[id];
        if (prev == null) {
          counts[id] = (materia: m, subtema: s, count: 1);
        } else {
          counts[id] = (
            materia: prev.materia,
            subtema: prev.subtema,
            count: prev.count + 1,
          );
        }
      }

      if (snap.docs.length < _pageSize) break;
      last = snap.docs.last;
    }

    await _replaceCatalog(counts);
    invalidateCache();
  }

  Future<void> _replaceCatalog(
    Map<String, ({String materia, String subtema, int count})> counts,
  ) async {
    final existing = await _catalogCol.get();
    for (var i = 0; i < existing.docs.length; i += _pageSize) {
      final batch = _db.batch();
      final end = i + _pageSize > existing.docs.length
          ? existing.docs.length
          : i + _pageSize;
      for (var j = i; j < end; j++) {
        batch.delete(existing.docs[j].reference);
      }
      await batch.commit();
    }

    if (counts.isEmpty) return;

    final entries = counts.entries.toList();
    for (var i = 0; i < entries.length; i += _pageSize) {
      final batch = _db.batch();
      final end =
          i + _pageSize > entries.length ? entries.length : i + _pageSize;
      for (var j = i; j < end; j++) {
        final e = entries[j];
        final ref = _catalogCol.doc(e.key);
        batch.set(ref, {
          'materia': e.value.materia,
          'subtema': e.value.subtema,
          'cardCount': e.value.count,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
