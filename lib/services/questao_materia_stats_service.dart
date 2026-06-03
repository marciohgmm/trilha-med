import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../models/flashcard_materia_stat.dart';
import '../services/auth/admin_auth_service.dart';
import '../utils/content_hierarchy_utils.dart';

/// Catálogo agregado por matéria para questões (lista de matérias / simulado).
class QuestaoMateriaStatsService {
  QuestaoMateriaStatsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final QuestaoMateriaStatsService instance =
      QuestaoMateriaStatsService();

  final FirebaseFirestore _db;

  static const _pageSize = 400;

  CollectionReference<Map<String, dynamic>> get _statsCol =>
      _db.collection(FirestorePaths.questoesMateriaStats);

  Stream<List<FlashcardMateriaStat>> watchMateriaStats() {
    return _statsCol.orderBy('name').snapshots().map((snap) {
      return snap.docs
          .map((d) => FlashcardMateriaStat.fromDoc(d.id, d.data()))
          .where((s) => s.name.isNotEmpty && s.total > 0)
          .toList();
    });
  }

  Future<List<FlashcardMateriaStat>> fetchMateriaStats() async {
    await ensureSeededIfEmpty();
    final snap = await _statsCol.orderBy('name').get();
    return snap.docs
        .map((d) => FlashcardMateriaStat.fromDoc(d.id, d.data()))
        .where((s) => s.name.isNotEmpty && s.total > 0)
        .toList();
  }

  Future<void> ensureSeededIfEmpty() async {
    try {
      final probe = await _statsCol.limit(1).get();
      if (probe.docs.isNotEmpty) return;
      final access = await AdminAuthService().resolveAccess();
      if (!access.allowed) return;
      await rebuildFromQuestoes();
    } catch (e, st) {
      debugPrint('[QuestaoMateriaStatsService] ensureSeededIfEmpty: $e\n$st');
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

  Future<void> rebuildFromQuestoes() async {
    final counts = <String, int>{};
    DocumentSnapshot<Map<String, dynamic>>? last;

    while (true) {
      Query<Map<String, dynamic>> q = _db
          .collection(FirestorePaths.questoes)
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
}
