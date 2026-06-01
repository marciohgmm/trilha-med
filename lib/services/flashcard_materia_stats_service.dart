import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../models/flashcard_materia_stat.dart';
import '../utils/content_hierarchy_utils.dart';

/// Catálogo agregado por matéria — evita `snapshots()` / `get()` na coleção `flashcards` na Home.
class FlashcardMateriaStatsService {
  FlashcardMateriaStatsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final FlashcardMateriaStatsService instance =
      FlashcardMateriaStatsService();

  final FirebaseFirestore _db;

  static const _pageSize = 400;
  static const _whereInChunk = 10;

  CollectionReference<Map<String, dynamic>> get _statsCol =>
      _db.collection(FirestorePaths.flashcardsMateriaStats);

  Future<List<FlashcardMateriaStat>> fetchMateriaStats() async {
    await ensureSeededIfEmpty();
    final snap = await _statsCol.orderBy('name').get();
    return snap.docs
        .map((d) => FlashcardMateriaStat.fromDoc(d.id, d.data()))
        .where((s) => s.name.isNotEmpty && s.total > 0)
        .toList();
  }

  /// Stream do catálogo (~dezenas de documentos, não toda a coleção `flashcards`).
  Stream<List<FlashcardMateriaStat>> watchMateriaStats() {
    return _statsCol.orderBy('name').snapshots().map((snap) {
      return snap.docs
          .map((d) => FlashcardMateriaStat.fromDoc(d.id, d.data()))
          .where((s) => s.name.isNotEmpty && s.total > 0)
          .toList();
    });
  }

  /// Se o catálogo estiver vazio, reconstrói uma vez (migração / primeiro deploy).
  Future<void> ensureSeededIfEmpty() async {
    try {
      final probe = await _statsCol.limit(1).get();
      if (probe.docs.isNotEmpty) return;
      await rebuildFromFlashcards();
    } catch (e, st) {
      debugPrint('[FlashcardMateriaStatsService] ensureSeededIfEmpty: $e\n$st');
    }
  }

  Future<void> incrementMateria(String materia) async {
    final name = materia.trim();
    if (name.isEmpty) return;
    final ref = _statsCol.doc(ContentHierarchyUtils.materiaCatalogDocId(name));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'total': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'name': name,
          'total': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> decrementMateria(String materia, {int by = 1}) async {
    final name = materia.trim();
    if (name.isEmpty || by <= 0) return;
    final ref = _statsCol.doc(ContentHierarchyUtils.materiaCatalogDocId(name));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['total'] as num?)?.toInt() ?? 0;
      final next = current - by;
      if (next <= 0) {
        tx.delete(ref);
      } else {
        tx.update(ref, {
          'total': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Recontagem completa (admin / seed inicial) — paginada, sem listener global.
  Future<void> rebuildFromFlashcards() async {
    final counts = <String, int>{};
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
        if (m.isNotEmpty) {
          counts[m] = (counts[m] ?? 0) + 1;
        }
      }

      if (snap.docs.length < _pageSize) break;
      last = snap.docs.last;
    }

    await _replaceCatalog(counts);
  }

  Future<void> _replaceCatalog(Map<String, int> counts) async {
    final existing = await _statsCol.get();
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
        final name = entries[j].key;
        final total = entries[j].value;
        final ref =
            _statsCol.doc(ContentHierarchyUtils.materiaCatalogDocId(name));
        batch.set(ref, {
          'name': name,
          'total': total,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Progresso por matéria a partir de `users/{uid}/progresso` (sem varrer flashcards).
  Future<Map<String, int>> computeEstudadosPorMateria(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> progressoDocs,
  ) async {
    final porMateria = <String, int>{};
    final idsSemMateria = <String>[];

    for (final doc in progressoDocs) {
      final m = (doc.data()['materia'] ?? '').toString().trim();
      if (m.isNotEmpty) {
        porMateria[m] = (porMateria[m] ?? 0) + 1;
      } else {
        idsSemMateria.add(doc.id);
      }
    }

    if (idsSemMateria.isEmpty) return porMateria;

    for (var i = 0; i < idsSemMateria.length; i += _whereInChunk) {
      final end = i + _whereInChunk > idsSemMateria.length
          ? idsSemMateria.length
          : i + _whereInChunk;
      final chunk = idsSemMateria.sublist(i, end);
      final snap = await _db
          .collection(FirestorePaths.flashcards)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final card in snap.docs) {
        final m = (card.data()['materia'] ?? '').toString().trim();
        if (m.isNotEmpty) {
          porMateria[m] = (porMateria[m] ?? 0) + 1;
        }
      }
    }

    return porMateria;
  }

  List<MateriaHomeProgress> buildHomeRows({
    required List<FlashcardMateriaStat> stats,
    required Map<String, int> estudadosPorMateria,
  }) {
    final byName = {for (final s in stats) s.name: s};
    final materias = ContentHierarchyUtils.sortAlphabetically(byName.keys);

    return materias.map((materia) {
      final total = byName[materia]?.total ?? 0;
      final rawEstudados = estudadosPorMateria[materia] ?? 0;
      final estudados = rawEstudados > total ? total : rawEstudados;
      return MateriaHomeProgress(
        materia: materia,
        total: total,
        estudados: estudados,
      );
    }).toList();
  }
}
