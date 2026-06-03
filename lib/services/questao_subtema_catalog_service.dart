import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../models/questao_subtema_catalog_entry.dart';
import '../services/auth/admin_auth_service.dart';
import '../utils/content_hierarchy_utils.dart';

/// Catálogo matéria/subtema para questões — evita varrer `questoes` na navegação.
class QuestaoSubtemaCatalogService {
  QuestaoSubtemaCatalogService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final QuestaoSubtemaCatalogService instance =
      QuestaoSubtemaCatalogService();

  final FirebaseFirestore _db;

  static const _pageSize = 400;

  CollectionReference<Map<String, dynamic>> get _catalogCol =>
      _db.collection(FirestorePaths.questoesSubtemaCatalog);

  Stream<List<QuestaoSubtemaCatalogEntry>> watchByMateria(String materia) {
    final m = materia.trim();
    return _catalogCol
        .where('materia', isEqualTo: m)
        .snapshots()
        .map((snap) => _mapEntries(snap.docs));
  }

  Future<List<String>> fetchSubtemasByMateria(String materia) async {
    await ensureSeededIfEmpty();
    final snap =
        await _catalogCol.where('materia', isEqualTo: materia.trim()).get();
    return ContentHierarchyUtils.sortAlphabetically(
      _mapEntries(snap.docs).map((e) => e.subtema),
    );
  }

  List<QuestaoSubtemaCatalogEntry> _mapEntries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((d) => QuestaoSubtemaCatalogEntry.fromDoc(d.id, d.data()))
        .where((e) =>
            e.materia.isNotEmpty && e.subtema.isNotEmpty && e.questaoCount > 0)
        .toList();
  }

  Future<void> ensureSeededIfEmpty() async {
    try {
      final probe = await _catalogCol.limit(1).get();
      if (probe.docs.isNotEmpty) return;
      final access = await AdminAuthService().resolveAccess();
      if (!access.allowed) return;
      await rebuildFromQuestoes();
    } catch (e, st) {
      debugPrint('[QuestaoSubtemaCatalogService] ensureSeededIfEmpty: $e\n$st');
    }
  }

  Future<void> registerQuestao(String materia, String subtema) async {
    final m = materia.trim();
    final s = subtema.trim();
    if (m.isEmpty || s.isEmpty) return;

    final ref = _catalogCol.doc(ContentHierarchyUtils.subtemaCatalogDocId(m, s));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'questaoCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'materia': m,
          'subtema': s,
          'questaoCount': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> unregisterQuestao(String materia, String subtema, {int by = 1}) async {
    final m = materia.trim();
    final s = subtema.trim();
    if (m.isEmpty || s.isEmpty || by <= 0) return;

    final ref = _catalogCol.doc(ContentHierarchyUtils.subtemaCatalogDocId(m, s));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['questaoCount'] as num?)?.toInt() ?? 0;
      final next = current - by;
      if (next <= 0) {
        tx.delete(ref);
      } else {
        tx.update(ref, {
          'questaoCount': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> rebuildFromQuestoes() async {
    final counts = <String, ({String materia, String subtema, int count})>{};

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
          'questaoCount': e.value.count,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
