import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/osce_models.dart';

class OsceRoomService {
  OsceRoomService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String rooms = 'osce_rooms';
  static const String cases = 'osce_cases';
  static const String participants = 'participants';
  static const String metaCounters = 'osce_meta/counters';

  /// Status exibidos no lobby (exclui `ended` e `evaluating`, como o filtro legado).
  static const List<String> _lobbyOpenStatusKeys = [
    'waiting',
    'selectingCase',
    'ready',
    'running',
  ];

  CollectionReference<Map<String, dynamic>> get _roomsCol =>
      _db.collection(rooms);

  DocumentReference<Map<String, dynamic>> _room(String id) => _roomsCol.doc(id);

  CollectionReference<Map<String, dynamic>> _participantsCol(String roomId) =>
      _room(roomId).collection(participants);

  Future<int> _allocateRoomNumber() async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await _allocateRoomNumberTransaction();
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 150 * (attempt + 1)),
          );
        }
      }
    }
    return _allocateRoomNumberFromLatestRoom(lastError);
  }

  Future<int> _allocateRoomNumberTransaction() async {
    final ref = _db.doc(metaCounters);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final last = (snap.data()?['lastRoomNumber'] as num?)?.toInt() ?? 0;
      final next = last + 1;
      tx.set(ref, {'lastRoomNumber': next}, SetOptions(merge: true));
      return next;
    });
  }

  /// Fallback sem varrer a coleção inteira (compatível com S3).
  Future<int> _allocateRoomNumberFromLatestRoom(Object? cause) async {
    try {
      final snap = await _roomsCol
          .orderBy('roomNumber', descending: true)
          .limit(1)
          .get();
      var max = 0;
      if (snap.docs.isNotEmpty) {
        max = (snap.docs.first.data()['roomNumber'] as num?)?.toInt() ?? 0;
      }
      return max + 1;
    } catch (e) {
      if (cause != null) {
        throw Exception('Falha ao alocar número da sala: $cause');
      }
      rethrow;
    }
  }

  /// Salas abertas no lobby — query filtrada (V2); requer índice `status` + `roomNumber`.
  Stream<List<OsceRoomModel>> streamAllOpenRooms() {
    return _roomsCol
        .where('status', whereIn: _lobbyOpenStatusKeys)
        .orderBy('roomNumber')
        .snapshots()
        .map((s) {
      final list = s.docs.map(OsceRoomModel.fromDoc).toList();
      list.sort((a, b) {
        if (a.roomNumber != b.roomNumber) {
          return a.roomNumber.compareTo(b.roomNumber);
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    });
  }

  Stream<OsceRoomModel?> streamRoom(String roomId) {
    return _room(roomId).snapshots().map((d) {
      if (!d.exists) return null;
      return OsceRoomModel.fromDoc(d);
    });
  }

  Stream<List<OsceParticipantModel>> streamParticipants(String roomId) {
    return _participantsCol(roomId).snapshots().map(
          (s) => s.docs.map(OsceParticipantModel.fromDoc).toList(),
        );
  }

  Stream<int> streamParticipantCount(String roomId) {
    return streamParticipants(roomId).map((list) => list.length);
  }

  Future<OsceCaseModel?> getCase(String? caseId) async {
    if (caseId == null || caseId.isEmpty) return null;
    final doc = await _db.collection(cases).doc(caseId).get();
    if (!doc.exists) return null;
    return OsceCaseModel.fromDoc(doc);
  }

  Stream<List<OsceCaseModel>> streamCases({String? specialtyFilter}) {
    return _db.collection(cases).snapshots().map((s) {
      var list = s.docs.map(OsceCaseModel.fromDoc).toList();
      if (specialtyFilter != null &&
          specialtyFilter.isNotEmpty &&
          specialtyFilter != OsceSpecialties.allLabel) {
        list = list
            .where((c) => c.specialty.trim() == specialtyFilter.trim())
            .toList();
      }
      return list;
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<({String roomId, String? joinCode, int roomNumber})> createRoom({
    required String hostId,
    required String hostDisplayName,
    required bool isPublic,
    String? caseId,
    String? specialty,
  }) async {
    final roomNumber = await _allocateRoomNumber();
    final ref = _roomsCol.doc();
    final code = isPublic ? null : _generateCode();
    final name = 'Sala $roomNumber';

    await ref.set({
      'roomNumber': roomNumber,
      'name': name,
      'specialty': specialty ?? '',
      'isPublic': isPublic,
      'joinCode': code,
      'hostId': hostId,
      'caseId': caseId,
      'status': caseId != null && caseId.isNotEmpty
          ? OsceRoomStatus.ready.name
          : OsceRoomStatus.waiting.name,
      'stationStarted': false,
      'timerDurationSec': 600,
      'timerStartedAt': null,
      'timerEndsAt': null,
      'evaluatorUserId': null,
      'evaluatedUserId': null,
      'actorUserId': null,
      'doctorUserId': null,
      'exams': {
        'physical': OsceExamSlot().toMap(),
        'laboratory': OsceExamSlot().toMap(),
        'imaging': OsceExamSlot().toMap(),
      },
      'participantCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _participantsCol(ref.id).doc(hostId).set({
      'displayName': hostDisplayName,
      'role': OsceParticipantRole.spectator.firestoreValue,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return (roomId: ref.id, joinCode: code, roomNumber: roomNumber);
  }

  Future<bool> verifyJoinCode(String roomId, String code) async {
    final snap = await _room(roomId).get();
    if (!snap.exists) return false;
    final room = OsceRoomModel.fromDoc(snap);
    if (room.isPublic) return true;
    return room.joinCode?.toUpperCase() == code.trim().toUpperCase();
  }

  Future<String?> joinRoomByCode({
    required String code,
    required String userId,
    required String displayName,
  }) async {
    final snap = await _roomsCol
        .where('joinCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    await _joinRoom(snap.docs.first.id, userId, displayName);
    return snap.docs.first.id;
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String displayName,
    String? joinCode,
  }) async {
    final snap = await _room(roomId).get();
    if (!snap.exists) throw Exception('Sala não encontrada');
    final room = OsceRoomModel.fromDoc(snap);
    if (!room.isPublic) {
      if (joinCode == null ||
          room.joinCode?.toUpperCase() != joinCode.trim().toUpperCase()) {
        throw Exception('Código incorreto');
      }
    }
    await _joinRoom(roomId, userId, displayName);
  }

  Future<void> _joinRoom(
    String roomId,
    String userId,
    String displayName,
  ) async {
    final pref = _participantsCol(roomId).doc(userId);
    if ((await pref.get()).exists) return;

    await _db.runTransaction((tx) async {
      final r = await tx.get(_room(roomId));
      if (!r.exists) return;
      tx.update(_room(roomId), {
        'participantCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await pref.set({
      'displayName': displayName,
      'role': OsceParticipantRole.spectator.firestoreValue,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    final pref = await _participantsCol(roomId).doc(userId).get();
    if (!pref.exists) return;

    final roomSnap = await _room(roomId).get();
    if (!roomSnap.exists) return;
    final room = OsceRoomModel.fromDoc(roomSnap);

    await pref.reference.delete();

    final updates = <String, dynamic>{
      'participantCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (room.evaluatedUserId == userId) {
      updates['evaluatedUserId'] = null;
      updates['doctorUserId'] = null;
      if (room.stationStarted) {
        updates['stationStarted'] = false;
        updates['timerStartedAt'] = null;
        updates['timerEndsAt'] = null;
        updates['status'] = OsceRoomStatus.waiting.name;
      }
    }
    if (room.evaluatorUserId == userId) {
      updates['evaluatorUserId'] = null;
      updates['actorUserId'] = null;
    }

    await _room(roomId).update(updates);
    await _closeRoomIfEmpty(roomId);
  }

  Future<void> _closeRoomIfEmpty(String roomId) async {
    final remaining = await _participantsCol(roomId).limit(1).get();
    if (remaining.docs.isNotEmpty) return;

    await _room(roomId).update({
      'status': OsceRoomStatus.ended.name,
      'stationStarted': false,
      'timerStartedAt': null,
      'timerEndsAt': null,
      'evaluatedUserId': null,
      'evaluatorUserId': null,
      'doctorUserId': null,
      'actorUserId': null,
      'participantCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assumeEvaluator(String roomId, String userId) async {
    final room = await _requireRoom(roomId);
    if (room.stationStarted) {
      throw Exception('Não é possível trocar avaliador com estação em andamento');
    }

    final parts = await _participantsCol(roomId).get();
    final batch = _db.batch();

    for (final d in parts.docs) {
      final role = OsceParticipantRole.fromValue(d.data()['role']?.toString());
      if (d.id == userId) {
        batch.update(d.reference, {
          'role': OsceParticipantRole.evaluator.firestoreValue,
        });
      } else if (role == OsceParticipantRole.evaluator) {
        batch.update(d.reference, {
          'role': OsceParticipantRole.spectator.firestoreValue,
        });
      }
    }

    batch.update(_room(roomId), {
      'evaluatorUserId': userId,
      'actorUserId': userId,
      'status': OsceRoomStatus.selectingCase.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> assignEvaluator(
    String roomId,
    String evaluatorId,
    String requesterId,
  ) async {
    final room = await _requireRoom(roomId);
    if (room.evaluatorUserId != requesterId) {
      throw Exception('Somente o avaliador pode designar outro avaliador');
    }
    if (room.stationStarted) {
      throw Exception('Estação já iniciada');
    }
    await assumeEvaluator(roomId, evaluatorId);
  }

  Future<void> assumeEvaluated(String roomId, String userId) async {
    final room = await _requireRoom(roomId);
    if (room.stationStarted) {
      throw Exception('Troque o médico apenas antes de iniciar a estação');
    }

    final parts = await _participantsCol(roomId).get();
    final batch = _db.batch();

    for (final d in parts.docs) {
      final role = OsceParticipantRole.fromValue(d.data()['role']?.toString());
      if (d.id == userId) {
        batch.update(d.reference, {
          'role': OsceParticipantRole.evaluated.firestoreValue,
        });
      } else if (role == OsceParticipantRole.evaluated) {
        batch.update(d.reference, {
          'role': OsceParticipantRole.spectator.firestoreValue,
        });
      }
    }

    batch.update(_room(roomId), {
      'evaluatedUserId': userId,
      'doctorUserId': userId,
      'status': room.caseId != null
          ? OsceRoomStatus.ready.name
          : OsceRoomStatus.waiting.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> assignEvaluated(
    String roomId,
    String evaluatedId,
    String requesterId,
  ) async {
    final room = await _requireRoom(roomId);
    if (room.evaluatorUserId != requesterId) {
      throw Exception('Somente o avaliador pode designar o médico');
    }
    await assumeEvaluated(roomId, evaluatedId);
  }

  Future<void> clearEvaluated(String roomId, String requesterId) async {
    final room = await _requireRoom(roomId);
    if (room.evaluatorUserId != requesterId) {
      throw Exception('Somente o avaliador pode remover o médico');
    }
    if (room.stationStarted) {
      throw Exception('Não é possível remover médico durante a estação');
    }

    final evaluatedId = room.evaluatedUserId;
    if (evaluatedId != null) {
      await _participantsCol(roomId).doc(evaluatedId).update({
        'role': OsceParticipantRole.spectator.firestoreValue,
      });
    }
    await _room(roomId).update({
      'evaluatedUserId': null,
      'doctorUserId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> selectCase(String roomId, String caseId, String specialty) async {
    await _room(roomId).update({
      'caseId': caseId,
      'specialty': specialty,
      'status': OsceRoomStatus.ready.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Encerra a estação e abre fase de avaliação (todos na tela de notas).
  Future<void> linkEvaluation({
    required String roomId,
    required String evaluationId,
  }) async {
    await _room(roomId).update({
      'stationStarted': false,
      'status': OsceRoomStatus.evaluating.name,
      'evaluationId': evaluationId,
      'timerStartedAt': null,
      'timerEndsAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeRoomAfterEvaluation(String roomId) async {
    await _room(roomId).update({
      'status': OsceRoomStatus.ended.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startStation(String roomId, String doctorUserId) async {
    final room = await _requireRoom(roomId);
    if (room.evaluatedUserId != doctorUserId) {
      throw Exception('Somente o médico avaliado pode iniciar');
    }
    if (room.caseId == null || room.caseId!.isEmpty) {
      throw Exception('Selecione um caso antes de iniciar');
    }
    final now = DateTime.now();
    final ends = now.add(Duration(seconds: room.timerDurationSec));
    await _room(roomId).update({
      'stationStarted': true,
      'status': OsceRoomStatus.running.name,
      'timerStartedAt': Timestamp.fromDate(now),
      'timerEndsAt': Timestamp.fromDate(ends),
      'exams.physical': OsceExamSlot().toMap(),
      'exams.laboratory': OsceExamSlot().toMap(),
      'exams.imaging': OsceExamSlot().toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestExam(String roomId, OsceExamType type) async {
    final key = _examKey(type);
    await _room(roomId).update({
      'exams.$key.requested': true,
      'exams.$key.requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> releaseExam(String roomId, OsceExamType type) async {
    final key = _examKey(type);
    await _room(roomId).update({
      'exams.$key.released': true,
      'exams.$key.releasedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _examKey(OsceExamType type) {
    switch (type) {
      case OsceExamType.physical:
        return 'physical';
      case OsceExamType.laboratory:
        return 'laboratory';
      case OsceExamType.imaging:
        return 'imaging';
    }
  }

  OsceParticipantRole effectiveRole(
    OsceRoomModel room,
    String userId,
    List<OsceParticipantModel> participants,
  ) {
    if (room.evaluatedUserId == userId) {
      return OsceParticipantRole.evaluated;
    }
    if (room.evaluatorUserId == userId) {
      return OsceParticipantRole.evaluator;
    }
    final p = participants.where((e) => e.userId == userId).firstOrNull;
    return p?.role ?? OsceParticipantRole.spectator;
  }

  bool isEvaluator(OsceRoomModel room, String userId) =>
      room.evaluatorUserId == userId;

  bool isEvaluated(OsceRoomModel room, String userId) =>
      room.evaluatedUserId == userId;

  Future<OsceRoomModel> _requireRoom(String roomId) async {
    final snap = await _room(roomId).get();
    if (!snap.exists) throw Exception('Sala não encontrada');
    return OsceRoomModel.fromDoc(snap);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
