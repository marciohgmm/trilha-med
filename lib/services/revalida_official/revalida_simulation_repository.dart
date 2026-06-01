import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../domain/revalida_official/revalida_evolution_summary.dart';
import '../../models/revalida_simulation_model.dart';

/// Persistência de simulados oficiais Revalida.
class RevalidaSimulationRepository {
  RevalidaSimulationRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const collection = FirestorePaths.revalidaSimulations;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collection);

  Future<String> save(RevalidaSimulationRecord record) async {
    final ref = _col.doc();
    await ref.set(record.toFirestoreMap());
    return ref.id;
  }

  Future<List<RevalidaSimulationRecord>> listForUser(String uid,
      {int limit = 20}) async {
    final snap = await _col
        .where('uid', isEqualTo: uid)
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => RevalidaSimulationRecord.fromDoc(d.id, d.data()))
        .toList();
  }

  Stream<List<RevalidaSimulationRecord>> watchForUser(String uid,
      {int limit = 20}) {
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => RevalidaSimulationRecord.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  RevalidaEvolutionSummary summarize(List<RevalidaSimulationRecord> records) =>
      summarizeRevalidaEvolution(records);
}
