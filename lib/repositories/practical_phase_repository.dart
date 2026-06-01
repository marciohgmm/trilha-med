import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/practical_phase_model.dart';
import '../utils/firestore_sanitize.dart';

/// Contrato de persistência da Fase Prática.
/// Implementação padrão: [FirestorePracticalPhaseRepository] (Firebase).
/// Para trocar backend, crie outra implementação e injete em [PracticalPhaseService].
abstract class PracticalPhaseRepository {
  static const String collectionName = 'practical_phase_models';

  Stream<List<PracticalPhaseModel>> watchAll();

  Stream<List<PracticalPhaseModel>> watchPublished();

  Future<PracticalPhaseModel?> getById(String id);

  Future<String> create(PracticalPhaseModel model);

  Future<void> update(String id, Map<String, dynamic> data);

  Future<void> delete(String id);

  Future<void> updateOrder(List<({String id, int order})> items);

  Future<bool> isEmpty();
}

class FirestorePracticalPhaseRepository implements PracticalPhaseRepository {
  FirestorePracticalPhaseRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(PracticalPhaseRepository.collectionName);

  @override
  Stream<List<PracticalPhaseModel>> watchAll() {
    return _col.orderBy('order').snapshots().map(_mapDocs);
  }

  @override
  Stream<List<PracticalPhaseModel>> watchPublished() {
    // Filtro publicado+ativo no cliente evita índice composto no Firestore.
    return _col.orderBy('order').snapshots().map((snap) {
      return _mapDocs(snap)
          .where((m) => m.visibleToStudents)
          .toList();
    });
  }

  List<PracticalPhaseModel> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((d) => PracticalPhaseModel.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<PracticalPhaseModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PracticalPhaseModel.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<String> create(PracticalPhaseModel model) async {
    final ref =
        model.id.trim().isNotEmpty ? _col.doc(model.id.trim()) : _col.doc();
    final data = sanitizeForFirestore(model.copyWith(id: ref.id).toMap());
    await ref.set(data);
    return ref.id;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final docId = id.trim();
    if (docId.isEmpty) {
      throw ArgumentError('ID do modelo inválido para atualização.');
    }
    final ref = _col.doc(docId);
    final sanitized = sanitizeForFirestore(Map<String, dynamic>.from(data));
    sanitized.remove('id');
    sanitized['updatedAt'] = FieldValue.serverTimestamp();

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(sanitized, SetOptions(merge: true));
      return;
    }
    await ref.update(sanitized);
  }

  @override
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  @override
  Future<void> updateOrder(List<({String id, int order})> items) async {
    final batch = _db.batch();
    for (final item in items) {
      batch.update(_col.doc(item.id), {
        'order': item.order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<bool> isEmpty() async {
    final snap = await _col.limit(1).get();
    return snap.docs.isEmpty;
  }
}
