import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/content_query_limits.dart';
import '../models/live_event_models.dart';
import '../models/questao_model.dart';
import 'auth/admin_auth_service.dart';
import 'questao_materia_stats_service.dart';
import 'questao_service.dart';

/// Eventos ao vivo — Firestore com streams em tempo real.
class LiveEventService {
  LiveEventService({
    FirebaseFirestore? firestore,
    AdminAuthService? adminAuth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _adminAuth = adminAuth ?? AdminAuthService();

  final FirebaseFirestore _db;
  final AdminAuthService _adminAuth;
  final QuestaoMateriaStatsService _questaoMateriaStats =
      QuestaoMateriaStatsService.instance;

  static const String collectionEvents = 'live_events';
  static const String subParticipants = 'participants';

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection(collectionEvents);

  DocumentReference<Map<String, dynamic>> _eventRef(String id) =>
      _events.doc(id);

  CollectionReference<Map<String, dynamic>> _participantsRef(String eventId) =>
      _eventRef(eventId).collection(subParticipants);

  /// Host do evento ou administrador (override manual no dashboard).
  Future<bool> canActAsEventCoordinator({
    required String eventId,
    String? userId,
    LiveEventModel? event,
  }) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    final admin = await _adminAuth.resolveAccess();
    if (admin.allowed) return true;

    final ev = event ?? await getEvent(eventId);
    if (ev == null) return false;
    if (!ev.hasHost) return false;
    return ev.isHost(uid);
  }

  Future<LiveEventModel?> getEvent(String eventId) async {
    final doc = await _eventRef(eventId).get();
    if (!doc.exists) return null;
    return LiveEventModel.fromDoc(doc);
  }

  Future<bool> _canActAsEventCoordinator(String eventId) =>
      canActAsEventCoordinator(eventId: eventId);

  Future<void> _requireEventCoordinator(String eventId) async {
    if (!await _canActAsEventCoordinator(eventId)) {
      throw StateError(
        'Apenas o host do evento ou um administrador pode executar esta ação.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  Stream<List<LiveEventModel>> streamPublishedEvents() {
    return _events
        .orderBy('scheduledAt')
        .limit(30)
        .snapshots()
        .map((s) => s.docs
            .map(LiveEventModel.fromDoc)
            .where((e) => e.status != LiveEventStatus.cancelled)
            .toList());
  }

  Stream<LiveEventModel?> streamEvent(String eventId) {
    return _eventRef(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LiveEventModel.fromDoc(doc);
    });
  }

  Stream<LiveEventParticipant?> streamParticipant(
    String eventId,
    String userId,
  ) {
    return _participantsRef(eventId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LiveEventParticipant.fromDoc(doc);
    });
  }

  Stream<List<LiveEventParticipant>> streamParticipants(String eventId) {
    return _participantsRef(eventId).snapshots().map((s) {
      final list = s.docs.map(LiveEventParticipant.fromDoc).toList();
      list.sort((a, b) => b.score.compareTo(a.score));
      return list.take(100).toList();
    });
  }

  Stream<List<LiveEventParticipant>> streamTopRanking(String eventId) =>
      streamParticipants(eventId);

  // ---------------------------------------------------------------------------
  // Admin CRUD
  // ---------------------------------------------------------------------------

  Future<List<String>> listarMateriasDoBanco() async {
    final stats = await _questaoMateriaStats.fetchMateriaStats();
    return stats.map((s) => s.name).toList()..sort();
  }

  Future<String> createEvent({
    required String description,
    required DateTime scheduledAt,
    required LiveEventGameMode gameMode,
    int livesPerPlayer = 3,
    int secondsPerQuestion = 30,
    String? poolMateria,
    LiveEventRewards rewards = const LiveEventRewards(),
    String? hostId,
    LiveEventPushAudience pushAudience = LiveEventPushAudience.participants,
  }) async {
    final host = hostId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (host.isEmpty) {
      throw StateError('Usuário não autenticado — não é possível definir o host.');
    }

    final now = DateTime.now();
    final ref = _events.doc();
    final filters = LiveEventQuestionFilters(
      materia: poolMateria,
    );
    await ref.set({
      'hostId': host,
      'type': LiveEventType.ultimoSobrevivente.value,
      'title': LiveEventType.ultimoSobrevivente.displayTitle,
      'description': description,
      'status': LiveEventStatus.scheduled.value,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'gameMode': gameMode.value,
      'livesPerPlayer': livesPerPlayer,
      'secondsPerQuestion': secondsPerQuestion,
      'maxParticipants': 999999,
      'questionCount': 0,
      'selectionMode': LiveQuestionSelectionMode.automatic.value,
      'filters': filters.toMap(),
      'manualQuestionIds': <String>[],
      'questions': <Map<String, dynamic>>[],
      'usedQuestionIds': <String>[],
      'rewards': rewards.toMap(),
      'pushAudience': pushAudience.value,
      'participantCount': 0,
      'survivorCount': 0,
      'eliminatedCount': 0,
      'currentRound': LiveEventCurrentRound(phase: LiveRoundPhase.lobby).toMap(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return ref.id;
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _requireEventCoordinator(eventId);
    await _eventRef(eventId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelEvent(String eventId) async {
    await updateEvent(eventId, {
      'status': LiveEventStatus.cancelled.value,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<QuestaoModel>> fetchQuestionsForPicker({
    String? materia,
    String? tema,
    String? subtema,
    String? dificuldade,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(QuestaoService.collectionQuestoes);
    if (materia != null && materia.isNotEmpty) {
      q = q.where('materia', isEqualTo: materia);
    }
    if (tema != null && tema.isNotEmpty) {
      q = q.where('tema', isEqualTo: tema);
    }
    if (subtema != null && subtema.isNotEmpty) {
      q = q.where('subtema', isEqualTo: subtema);
    }
    if (dificuldade != null && dificuldade.isNotEmpty) {
      q = q.where('dificuldade', isEqualTo: dificuldade);
    }
    final snap = await q.limit(ContentQueryLimits.maxPickerResults).get();
    return snap.docs
        .map((d) => QuestaoModel.fromMap(d.id, d.data()))
        .where((q) => q.disponivelParaEstudo)
        .toList();
  }

  Future<LiveEventQuestionSnapshot?> _sortearQuestao({
    required LiveEventModel event,
    required List<String> excludeIds,
  }) async {
    var candidatas = await fetchQuestionsForPicker(
      materia: event.filters.materia,
    );
    candidatas =
        candidatas.where((q) => !excludeIds.contains(q.id)).toList();
    if (candidatas.isEmpty) {
      final materias = await listarMateriasDoBanco()..shuffle(Random());
      for (final m in materias) {
        candidatas = await fetchQuestionsForPicker(materia: m);
        candidatas =
            candidatas.where((q) => !excludeIds.contains(q.id)).toList();
        if (candidatas.isNotEmpty) break;
      }
    }
    if (candidatas.isEmpty) return null;
    candidatas.shuffle(Random());
    return _snapshotFromQuestao(candidatas.first);
  }

  LiveEventQuestionSnapshot _snapshotFromQuestao(QuestaoModel q) {
    return LiveEventQuestionSnapshot(
      questaoId: q.id,
      enunciado: q.enunciado,
      alternativas: q.alternativas
          .map((a) => {'id': a.id, 'texto': a.texto})
          .toList(),
      corretaId: q.corretaId,
      materia: q.materia,
      tema: q.tema,
      subtema: q.subtema,
    );
  }

  Future<void> startEvent(String eventId) async {
    await _requireEventCoordinator(eventId);

    final doc = await _eventRef(eventId).get();
    if (!doc.exists) throw Exception('Evento não encontrado');
    final event = LiveEventModel.fromDoc(doc);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hostPatch = (!event.hasHost && uid.isNotEmpty) ? {'hostId': uid} : null;

    final first = await _sortearQuestao(event: event, excludeIds: []);
    if (first == null) {
      throw Exception('Nenhuma questão disponível no banco para este evento.');
    }

    final now = DateTime.now();
    final endsAt = now.add(Duration(seconds: event.secondsPerQuestion));

    await _eventRef(eventId).set({
      if (hostPatch != null) ...hostPatch,
      'status': LiveEventStatus.live.value,
      'startedAt': Timestamp.fromDate(now),
      'questions': <Map<String, dynamic>>[],
      'usedQuestionIds': [first.questaoId],
      'participantCount': FieldValue.increment(0),
      'survivorCount': event.participantCount,
      'eliminatedCount': 0,
      'currentRound': LiveEventCurrentRound(
        index: 0,
        phase: LiveRoundPhase.question,
        question: first,
        startedAt: now,
        endsAt: endsAt,
      ).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Ativa participantes registrados
    final parts = await _participantsRef(eventId).get();
    final batch = _db.batch();
    var active = 0;
    for (final p in parts.docs) {
      final data = p.data();
      final status = data['status']?.toString();
      if (status == ParticipantStatus.registered.value ||
          status == ParticipantStatus.active.value) {
        batch.update(p.reference, {
          'status': ParticipantStatus.active.value,
          'livesRemaining': event.livesPerPlayer,
        });
        active++;
      }
    }
    await batch.commit();
    await _eventRef(eventId).update({
      'survivorCount': active,
    });
  }

  Future<void> endEvent(String eventId) async {
    await _requireEventCoordinator(eventId);
    await _finalizeRankings(eventId);
    await _eventRef(eventId).set({
      'status': LiveEventStatus.ended.value,
      'endedAt': FieldValue.serverTimestamp(),
      'currentRound': LiveEventCurrentRound(
        phase: LiveRoundPhase.ended,
      ).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Participação
  // ---------------------------------------------------------------------------

  Future<void> joinEvent({
    required String eventId,
    required String userId,
    required String displayName,
    String? photoUrl,
  }) async {
    final eventSnap = await _eventRef(eventId).get();
    if (!eventSnap.exists) throw Exception('Evento não encontrado');
    final event = LiveEventModel.fromDoc(eventSnap);

    if (event.isEnded || event.status == LiveEventStatus.cancelled) {
      throw Exception('Evento encerrado.');
    }

    final pref = _participantsRef(eventId).doc(userId);
    final existing = await pref.get();
    if (existing.exists) return;

    final lives = event.gameMode == LiveEventGameMode.lives
        ? event.livesPerPlayer
        : 0;

    await pref.set({
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'status': event.isLive
          ? ParticipantStatus.active.value
          : ParticipantStatus.registered.value,
      'livesRemaining': lives,
      'correctAnswers': 0,
      'totalResponseTimeMs': 0,
      'score': 0,
      'xpEarned': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await _eventRef(eventId).update({
      'participantCount': FieldValue.increment(1),
      if (!event.isLive) 'survivorCount': FieldValue.increment(1),
    });
  }

  Future<void> switchToSpectator(String eventId, String userId) async {
    await _participantsRef(eventId).doc(userId).update({
      'status': ParticipantStatus.spectator.value,
    });
  }

  Future<void> submitAnswer({
    required String eventId,
    required String userId,
    required String alternativeId,
    required int roundIndex,
  }) async {
    final eventSnap = await _eventRef(eventId).get();
    if (!eventSnap.exists) return;
    final event = LiveEventModel.fromDoc(eventSnap);
    final round = event.currentRound;
    if (round.phase != LiveRoundPhase.question) return;
    if (round.index != roundIndex) return;
    if (round.question == null) return;

    final pref = await _participantsRef(eventId).doc(userId).get();
    if (!pref.exists) return;
    final part = LiveEventParticipant.fromDoc(pref);
    if (!part.isActive) return;
    if (part.lastAnswerRound == roundIndex) return;

    final started = round.startedAt ?? DateTime.now();
    final responseMs =
        DateTime.now().difference(started).inMilliseconds.clamp(0, 999999);
    final correct = alternativeId == round.question!.corretaId;

    await _participantsRef(eventId).doc(userId).update({
      'lastAnswerRound': roundIndex,
      'lastAnswerAlternativeId': alternativeId,
      'lastAnswerCorrect': correct,
      'lastAnswerAt': FieldValue.serverTimestamp(),
      'pendingResponseTimeMs': responseMs,
    });
  }

  /// Tempo esgotou na questão → fase de revelação.
  Future<void> advanceToReveal(String eventId) async {
    if (!await _canActAsEventCoordinator(eventId)) return;

    await _db.runTransaction((tx) async {
      final ref = _eventRef(eventId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final event = LiveEventModel.fromDoc(snap);
      if (event.status != LiveEventStatus.live) return;
      final round = event.currentRound;
      if (round.phase != LiveRoundPhase.question) return;
      final endsAt = round.endsAt;
      if (endsAt != null && DateTime.now().isBefore(endsAt.subtract(const Duration(milliseconds: 500)))) {
        return;
      }
      tx.update(ref, {
        'currentRound': {
          ...round.toMap(),
          'phase': LiveRoundPhase.reveal.value,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Após revelação → processa eliminações e próxima questão (ou encerra).
  Future<void> advanceFromReveal(String eventId) async {
    if (!await _canActAsEventCoordinator(eventId)) return;

    final eventRef = _eventRef(eventId);
    var roundIndex = -1;

    final claimed = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(eventRef);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final event = LiveEventModel.fromDoc(snap);
      if (event.status != LiveEventStatus.live) return false;
      if (event.currentRound.phase != LiveRoundPhase.reveal) return false;

      roundIndex = event.currentRound.index;
      final processed = (data['revealProcessedIndex'] as num?)?.toInt();
      if (processed == roundIndex) return false;

      tx.update(eventRef, {
        'revealProcessedIndex': roundIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (claimed != true) return;

    final eventSnap = await eventRef.get();
    if (!eventSnap.exists) return;
    final event = LiveEventModel.fromDoc(eventSnap);
    if (event.status != LiveEventStatus.live) return;
    if (event.currentRound.phase != LiveRoundPhase.reveal) return;

    final round = event.currentRound;
    final question = round.question;
    if (question == null) return;

    final partsSnap = await _participantsRef(eventId).get();
    var correct = 0;
    var wrong = 0;
    var skipped = 0;

    final batch = _db.batch();

    for (final doc in partsSnap.docs) {
      final data = doc.data();
      if (data['status'] != ParticipantStatus.active.value) continue;

      final lastRound = (data['lastAnswerRound'] as num?)?.toInt();
      final answered = lastRound == round.index;
      final isCorrect = data['lastAnswerCorrect'] == true;
      final responseMs = (data['pendingResponseTimeMs'] as num?)?.toInt() ?? 0;

      if (!answered) {
        skipped++;
        _eliminateOrLifeBatch(batch, doc.reference, data, event, round.index);
        continue;
      }

      if (isCorrect) {
        correct++;
        final newCorrect = ((data['correctAnswers'] as num?)?.toInt() ?? 0) + 1;
        final newTime =
            ((data['totalResponseTimeMs'] as num?)?.toInt() ?? 0) + responseMs;
        batch.update(doc.reference, {
          'correctAnswers': newCorrect,
          'totalResponseTimeMs': newTime,
          'score': _calcScore(newCorrect, newTime),
        });
      } else {
        wrong++;
        _eliminateOrLifeBatch(batch, doc.reference, data, event, round.index);
      }
    }

    await batch.commit();

    var survivors = 0;
    var eliminated = 0;
    final afterSnap = await _participantsRef(eventId).get();
    for (final doc in afterSnap.docs) {
      final st = doc.data()['status']?.toString();
      if (st == ParticipantStatus.active.value) survivors++;
      if (st == ParticipantStatus.eliminated.value) eliminated++;
    }

    if (survivors <= 1) {
      await _eventRef(eventId).update({
        'survivorCount': survivors,
        'eliminatedCount': eliminated,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await endEvent(eventId);
      return;
    }

    final usedIds = List<String>.from(
      (eventSnap.data()?['usedQuestionIds'] as List?)?.map((e) => e.toString()) ??
          [],
    );
    if (round.question != null) {
      usedIds.add(round.question!.questaoId);
    }

    final next = await _sortearQuestao(event: event, excludeIds: usedIds);
    if (next == null) {
      await endEvent(eventId);
      return;
    }
    usedIds.add(next.questaoId);

    final now = DateTime.now();
    final nextIndex = round.index + 1;
    await _eventRef(eventId).update({
      'usedQuestionIds': usedIds,
      'currentRound': LiveEventCurrentRound(
        index: nextIndex,
        phase: LiveRoundPhase.question,
        question: next,
        startedAt: now,
        endsAt: now.add(Duration(seconds: event.secondsPerQuestion)),
        correctCount: correct,
        wrongCount: wrong,
        skippedCount: skipped,
      ).toMap(),
      'survivorCount': survivors,
      'eliminatedCount': eliminated,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _eliminateOrLifeBatch(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> pref,
    Map<String, dynamic> data,
    LiveEventModel event,
    int roundIndex,
  ) {
    if (event.gameMode == LiveEventGameMode.lives) {
      var lives = (data['livesRemaining'] as num?)?.toInt() ?? 0;
      lives = max(0, lives - 1);
      if (lives > 0) {
        batch.update(pref, {'livesRemaining': lives});
        return;
      }
    }
    batch.update(pref, {
      'status': ParticipantStatus.eliminated.value,
      'eliminatedAtRound': roundIndex,
    });
  }

  int _calcScore(int correctAnswers, int totalResponseTimeMs) {
    final timeBonus = max(0, 10000 - (totalResponseTimeMs ~/ max(1, correctAnswers)));
    return correctAnswers * 1000 + timeBonus;
  }

  Future<void> _finalizeRankings(String eventId) async {
    final snap = await _participantsRef(eventId).get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final sa = (a.data()['score'] as num?)?.toInt() ?? 0;
        final sb = (b.data()['score'] as num?)?.toInt() ?? 0;
        return sb.compareTo(sa);
      });
    final eventDoc = await _eventRef(eventId).get();
    final rewards = eventDoc.exists
        ? LiveEventRewards.fromMap(
            (eventDoc.data()?['rewards'] as Map<String, dynamic>?),
          )
        : const LiveEventRewards();

    final batch = _db.batch();
    var rank = 1;
    final xpByUser = <String, int>{};
    for (final doc in docs) {
      final xp = rank <= 10 ? rewards.xp ~/ max(1, rank) : rewards.xp ~/ 10;
      xpByUser[doc.id] = xp;
      batch.update(doc.reference, {
        'finalRank': rank,
        'xpEarned': xp,
      });
      rank++;
    }
    await batch.commit();

    for (final entry in xpByUser.entries) {
      if (entry.value > 0 || rewards.badgeId.isNotEmpty) {
        await grantRewardsToUser(
          eventId: eventId,
          userId: entry.key,
          xp: entry.value,
          badgeId: rewards.badgeId,
        );
      }
    }
  }

  static const String rewardPayoutsSubcollection = 'reward_payouts';

  /// Credita XP/badge em `users/{userId}` via payout + transação (rules D2).
  Future<void> grantRewardsToUser({
    required String eventId,
    required String userId,
    required int xp,
    required String badgeId,
  }) async {
    if (userId.isEmpty) return;

    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) {
      throw StateError('Usuário não autenticado.');
    }

    if (!await canActAsEventCoordinator(eventId: eventId)) {
      throw StateError(
        'Apenas o host do evento ou um administrador pode conceder recompensas.',
      );
    }

    final payoutRef = _eventRef(eventId)
        .collection(rewardPayoutsSubcollection)
        .doc(userId);
    final userRef = _db.collection('users').doc(userId);

    await _db.runTransaction((tx) async {
      tx.set(payoutRef, {
        'eventId': eventId,
        'targetUserId': userId,
        'xpAmount': xp,
        'badgeId': badgeId,
        'grantedBy': actor.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final userUpdate = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        '_liveEventRewardEventId': eventId,
      };
      if (xp > 0) {
        userUpdate['xp'] = FieldValue.increment(xp);
      }
      if (badgeId.isNotEmpty) {
        userUpdate['badges'] = FieldValue.arrayUnion([badgeId]);
      }

      tx.set(userRef, userUpdate, SetOptions(merge: true));
    });
  }
}
