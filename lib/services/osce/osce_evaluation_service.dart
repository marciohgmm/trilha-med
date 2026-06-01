import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/osce_default_evaluation_rubric.dart';
import '../../models/osce_evaluation_models.dart';
import '../../models/osce_models.dart';
import '../../utils/osce_specialty_mapper.dart';
import 'osce_evaluation_scoring.dart';
import 'osce_room_service.dart';

class OsceEvaluationService {
  OsceEvaluationService({
    FirebaseFirestore? db,
    OsceRoomService? roomService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _roomService = roomService ?? OsceRoomService();

  final FirebaseFirestore _db;
  final OsceRoomService _roomService;

  static const String collection = 'osce_evaluations';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collection);

  Stream<OsceEvaluationRecord?> streamByRoom(String roomId) {
    return _roomService.streamRoom(roomId).asyncExpand((room) {
      final id = room?.evaluationId;
      if (id == null || id.isEmpty) {
        return Stream<OsceEvaluationRecord?>.value(null);
      }
      return streamById(id);
    });
  }

  Stream<OsceEvaluationRecord?> streamById(String evaluationId) {
    return _col.doc(evaluationId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OsceEvaluationRecord.fromDoc(doc);
    });
  }

  Stream<List<OsceEvaluationRecord>> streamHistoryForUser(String userId) {
    return _col
        .where('evaluatedUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs
              .map(OsceEvaluationRecord.fromDoc)
              .where((r) => r.isFinalized)
              .toList(),
        );
  }

  /// Inicia avaliação ao encerrar estação (avaliador).
  Future<String> beginEvaluationForRoom({
    required OsceRoomModel room,
    required OsceCaseModel caseModel,
    required String evaluatorId,
    required String evaluatorName,
    required String evaluatedName,
  }) async {
    if (room.evaluatorUserId != evaluatorId) {
      throw Exception('Somente o avaliador pode iniciar a avaliação.');
    }

    final evaluatedId = room.evaluatedUserId;
    if (evaluatedId == null || evaluatedId.isEmpty) {
      throw Exception('Defina o médico avaliado antes de avaliar.');
    }

    final rubric = OsceDefaultEvaluationRubric.resolve(
      caseModel.evaluationRubric,
      fallbackDiagnosisText: caseModel.hiddenDiagnosis,
    );
    final specialtyKey = OsceSpecialtyMapper.specialtyToKey(
      caseModel.specialty.isNotEmpty ? caseModel.specialty : room.specialty,
    );

    final duration = room.timerStartedAt != null
        ? DateTime.now().difference(room.timerStartedAt!).inSeconds
        : room.timerDurationSec;

    final ref = _col.doc();
    final record = OsceEvaluationRecord(
      id: ref.id,
      roomId: room.id,
      caseId: caseModel.id,
      caseTitle: caseModel.title.isEmpty ? 'Caso OSCE' : caseModel.title,
      stationName: room.displayName,
      specialty: caseModel.specialty,
      specialtyKey: specialtyKey,
      evaluatorId: evaluatorId,
      evaluatorName: evaluatorName,
      evaluatedUserId: evaluatedId,
      evaluatedName: evaluatedName,
      status: OsceEvaluationStatus.draft,
      rubricSnapshot: rubric,
      criterionRatings: {},
      checkedItemIds: {},
      diagnosisLevel: OsceDiagnosisLevel.wrong,
      categoryScores: {},
      totalScore: 0,
      maxScore: OsceDefaultEvaluationRubric.maxTotal,
      correctCount: 0,
      totalChecklistItems: 0,
      performancePercent: 0,
      durationInSeconds: duration,
      stationStartedAt: room.timerStartedAt,
      createdAt: DateTime.now(),
    );

    await ref.set({
      ...record.toFirestoreMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _roomService.linkEvaluation(
      roomId: room.id,
      evaluationId: ref.id,
    );

    return ref.id;
  }

  Future<void> updateDraft({
    required String evaluationId,
    required Map<String, String> criterionRatings,
    required Map<String, List<String>> checkedItemIds,
    required OsceDiagnosisLevel diagnosisLevel,
    required OsceEvaluationRubric rubricSnapshot,
  }) async {
    final result = OsceEvaluationScoring.compute(
      rubric: rubricSnapshot,
      criterionRatings: criterionRatings,
      checkedItemIds: checkedItemIds,
      diagnosisLevel: diagnosisLevel,
    );

    await _col.doc(evaluationId).update({
      'criterionRatings': criterionRatings,
      'checkedItemIds': checkedItemIds,
      'diagnosisLevel': diagnosisLevel.firestoreValue,
      'categoryScores': result.categoryScores,
      'totalScore': result.totalScore,
      'maxScore': result.maxScore,
      'correctCount': result.correctCount,
      'totalChecklistItems': result.totalChecklistItems,
      'performancePercent': result.performancePercent,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<OsceEvaluationRecord> finalizeEvaluation({
    required String evaluationId,
    required String requesterId,
  }) async {
    final doc = await _col.doc(evaluationId).get();
    if (!doc.exists) throw Exception('Avaliação não encontrada');
    final record = OsceEvaluationRecord.fromDoc(doc);

    if (record.evaluatorId != requesterId) {
      throw Exception('Somente o avaliador pode finalizar a avaliação.');
    }
    if (record.isFinalized) return record;

    final rubric = OsceDefaultEvaluationRubric.resolve(record.rubricSnapshot);
    final result = OsceEvaluationScoring.compute(
      rubric: rubric,
      criterionRatings: record.criterionRatings,
      checkedItemIds: record.checkedItemIds,
      diagnosisLevel: record.diagnosisLevel,
    );

    await _col.doc(evaluationId).update({
      'status': 'finalized',
      'categoryScores': result.categoryScores,
      'totalScore': result.totalScore,
      'maxScore': result.maxScore,
      'correctCount': result.correctCount,
      'totalChecklistItems': result.totalChecklistItems,
      'performancePercent': result.performancePercent,
      'finalizedAt': FieldValue.serverTimestamp(),
    });

    await _roomService.closeRoomAfterEvaluation(record.roomId);

    final updated = await _col.doc(evaluationId).get();
    return OsceEvaluationRecord.fromDoc(updated);
  }
}
