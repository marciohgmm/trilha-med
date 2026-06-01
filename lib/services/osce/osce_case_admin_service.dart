import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/osce_default_case.dart';
import '../../models/osce_models.dart';
import '../../utils/osce_rich_text_storage.dart';
import '../osce/osce_room_service.dart';

/// CRUD de casos/temas OSCE (somente admin).
class OsceCaseAdminService {
  OsceCaseAdminService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(OsceRoomService.cases);

  Stream<List<OsceCaseModel>> streamAll() {
    return _col.snapshots().map((s) {
      final list = s.docs.map(OsceCaseModel.fromDoc).toList();
      list.sort((a, b) => a.title.compareTo(b.title));
      return list;
    });
  }

  Future<OsceCaseModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return OsceCaseModel.fromDoc(doc);
  }

  Future<String> save({
    required String id,
    required OsceCaseModel model,
  }) async {
    final ref = _col.doc(id);
    final exists = (await ref.get()).exists;

    final script = <String, String>{};
    model.actorScript.forEach((k, v) {
      script[k] = normalizeOsceRichStorage(v);
    });

    final data = <String, dynamic>{
      'title': model.title.trim().isEmpty ? 'Caso OSCE' : model.title.trim(),
      'specialty': model.specialty.trim(),
      'scenario': normalizeOsceRichStorage(model.scenario),
      'caseDescription': normalizeOsceRichStorage(model.caseDescription),
      'tasks': normalizeOsceRichStorage(model.tasks),
      'actorScript': script,
      'physicalExamContent': normalizeOsceRichStorage(model.physicalExamContent),
      'laboratoryContent': normalizeOsceRichStorage(model.laboratoryContent),
      'imagingContent': normalizeOsceRichStorage(model.imagingContent),
      'hiddenDiagnosis': normalizeOsceRichStorage(model.hiddenDiagnosis),
      'evaluationRubric': model.evaluationRubric.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (model.imagingImageUrl != null && model.imagingImageUrl!.isNotEmpty) {
      data['imagingImageUrl'] = model.imagingImageUrl;
    } else if (exists) {
      data['imagingImageUrl'] = FieldValue.delete();
    }
    if (!exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data);
    return id;
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<int> seedDefaultIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return 0;
    await _col.doc(OsceDefaultCase.defaultCaseId).set({
      ...OsceDefaultCase.firestoreMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 1;
  }
}
