import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/practical_phase_modules_seed.dart';
import '../models/practical_phase_module.dart';

class PracticalPhaseModuleService {
  PracticalPhaseModuleService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String collection = 'practical_phase_modules';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collection);

  Stream<List<PracticalPhaseModule>> streamPublished({
    bool includePremiumContent = true,
  }) {
    if (includePremiumContent) {
      return _col.orderBy('order').snapshots().map((snap) {
        return snap.docs
            .map((d) => PracticalPhaseModule.fromMap(d.id, d.data()))
            .where((m) => m.visibleToStudents)
            .toList();
      });
    }
    return _col
        .where('isPublished', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('requiresPremium', isEqualTo: false)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PracticalPhaseModule.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<PracticalPhaseModule>> streamAllAdmin() {
    return _col.orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((d) => PracticalPhaseModule.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Map<String, List<PracticalPhaseModule>> groupBySection(
    List<PracticalPhaseModule> modules,
  ) {
    final map = <String, List<PracticalPhaseModule>>{};
    for (final m in modules) {
      map.putIfAbsent(m.sectionKey, () => []).add(m);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    return map;
  }

  Future<int> seedIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return 0;
    var n = 0;
    for (final m in PracticalPhaseModulesSeed.defaults) {
      await _col.add(m.toMap());
      n++;
    }
    return n;
  }

  Future<String> save(PracticalPhaseModule module, {bool isNew = false}) async {
    if (isNew || module.id.isEmpty) {
      final ref = await _col.add({
        ...module.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
    await _col.doc(module.id).set(module.toMap(), SetOptions(merge: true));
    return module.id;
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> togglePublished(String id, bool value) =>
      _col.doc(id).update({'isPublished': value});

  Future<void> toggleActive(String id, bool value) =>
      _col.doc(id).update({'isActive': value});
}
