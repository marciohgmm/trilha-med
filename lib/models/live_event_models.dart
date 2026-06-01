import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de evento (extensível para torneios, campeonatos, etc.).
enum LiveEventType {
  ultimoSobrevivente('ultimo_sobrevivente');

  const LiveEventType(this.value);
  final String value;

  static LiveEventType? fromValue(String? v) {
    for (final t in LiveEventType.values) {
      if (t.value == v) return t;
    }
    return null;
  }

  String get displayTitle {
    switch (this) {
      case LiveEventType.ultimoSobrevivente:
        return 'Último Sobrevivente';
    }
  }

  String get emoji {
    switch (this) {
      case LiveEventType.ultimoSobrevivente:
        return '🔥';
    }
  }
}

enum LiveEventStatus {
  scheduled('scheduled'),
  upcoming('upcoming'),
  live('live'),
  ended('ended'),
  cancelled('cancelled');

  const LiveEventStatus(this.value);
  final String value;

  static LiveEventStatus fromValue(String? v) {
    return LiveEventStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => LiveEventStatus.scheduled,
    );
  }
}

enum LiveEventGameMode {
  elimination('elimination'),
  lives('lives');

  const LiveEventGameMode(this.value);
  final String value;

  static LiveEventGameMode fromValue(String? v) {
    return LiveEventGameMode.values.firstWhere(
      (e) => e.value == v,
      orElse: () => LiveEventGameMode.elimination,
    );
  }

  String get label {
    switch (this) {
      case LiveEventGameMode.elimination:
        return 'Eliminação direta';
      case LiveEventGameMode.lives:
        return 'Modo vidas';
    }
  }
}

enum LiveQuestionSelectionMode {
  automatic('automatic'),
  manual('manual');

  const LiveQuestionSelectionMode(this.value);
  final String value;

  static LiveQuestionSelectionMode fromValue(String? v) {
    return LiveQuestionSelectionMode.values.firstWhere(
      (e) => e.value == v,
      orElse: () => LiveQuestionSelectionMode.automatic,
    );
  }
}

enum LiveRoundPhase {
  lobby('lobby'),
  question('question'),
  reveal('reveal'),
  ended('ended');

  const LiveRoundPhase(this.value);
  final String value;

  static LiveRoundPhase fromValue(String? v) {
    return LiveRoundPhase.values.firstWhere(
      (e) => e.value == v,
      orElse: () => LiveRoundPhase.lobby,
    );
  }
}

/// Público de notificações push do evento (`live_events.pushAudience`).
enum LiveEventPushAudience {
  /// Inscritos em `participants` + host (padrão).
  participants('participants'),

  /// Divulgação explícita na criação — usuários ativos (7d) com pref de live.
  platformPublic('platform_public');

  const LiveEventPushAudience(this.value);
  final String value;

  static LiveEventPushAudience fromValue(String? v) {
    for (final a in LiveEventPushAudience.values) {
      if (a.value == v) return a;
    }
    return LiveEventPushAudience.participants;
  }

  String get label {
    switch (this) {
      case LiveEventPushAudience.participants:
        return 'Apenas inscritos no evento';
      case LiveEventPushAudience.platformPublic:
        return 'Plataforma (ativos 7 dias)';
    }
  }
}

enum ParticipantStatus {
  registered('registered'),
  active('active'),
  eliminated('eliminated'),
  spectator('spectator');

  const ParticipantStatus(this.value);
  final String value;

  static ParticipantStatus fromValue(String? v) {
    return ParticipantStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => ParticipantStatus.registered,
    );
  }
}

class LiveEventRewards {
  final int xp;
  final String badgeId;
  final String badgeLabel;
  final String titleReward;
  final int coins;

  const LiveEventRewards({
    this.xp = 500,
    this.badgeId = 'ultimo_sobrevivente',
    this.badgeLabel = 'Sobrevivente',
    this.titleReward = '',
    this.coins = 0,
  });

  factory LiveEventRewards.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const LiveEventRewards();
    return LiveEventRewards(
      xp: (m['xp'] as num?)?.toInt() ?? 500,
      badgeId: (m['badgeId'] ?? 'ultimo_sobrevivente').toString(),
      badgeLabel: (m['badgeLabel'] ?? 'Sobrevivente').toString(),
      titleReward: (m['titleReward'] ?? '').toString(),
      coins: (m['coins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'xp': xp,
        'badgeId': badgeId,
        'badgeLabel': badgeLabel,
        'titleReward': titleReward,
        'coins': coins,
      };
}

class LiveEventQuestionFilters {
  final String? materia;
  final String? tema;
  final String? subtema;
  final String? dificuldade;

  const LiveEventQuestionFilters({
    this.materia,
    this.tema,
    this.subtema,
    this.dificuldade,
  });

  factory LiveEventQuestionFilters.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const LiveEventQuestionFilters();
    return LiveEventQuestionFilters(
      materia: m['materia']?.toString(),
      tema: m['tema']?.toString(),
      subtema: m['subtema']?.toString(),
      dificuldade: m['dificuldade']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (materia != null && materia!.isNotEmpty) 'materia': materia,
        if (tema != null && tema!.isNotEmpty) 'tema': tema,
        if (subtema != null && subtema!.isNotEmpty) 'subtema': subtema,
        if (dificuldade != null && dificuldade!.isNotEmpty)
          'dificuldade': dificuldade,
      };
}

class LiveEventQuestionSnapshot {
  final String questaoId;
  final String enunciado;
  final List<Map<String, String>> alternativas;
  final String corretaId;
  final String materia;
  final String tema;
  final String subtema;

  const LiveEventQuestionSnapshot({
    required this.questaoId,
    required this.enunciado,
    required this.alternativas,
    required this.corretaId,
    this.materia = '',
    this.tema = '',
    this.subtema = '',
  });

  factory LiveEventQuestionSnapshot.fromMap(Map<String, dynamic> m) {
    final altsRaw = m['alternativas'];
    final alts = <Map<String, String>>[];
    if (altsRaw is List) {
      for (final a in altsRaw) {
        if (a is Map) {
          alts.add({
            'id': (a['id'] ?? '').toString(),
            'texto': (a['texto'] ?? '').toString(),
          });
        }
      }
    }
    return LiveEventQuestionSnapshot(
      questaoId: (m['questaoId'] ?? '').toString(),
      enunciado: (m['enunciado'] ?? '').toString(),
      alternativas: alts,
      corretaId: (m['corretaId'] ?? '').toString(),
      materia: (m['materia'] ?? '').toString(),
      tema: (m['tema'] ?? '').toString(),
      subtema: (m['subtema'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'questaoId': questaoId,
        'enunciado': enunciado,
        'alternativas': alternativas,
        'corretaId': corretaId,
        'materia': materia,
        'tema': tema,
        'subtema': subtema,
      };
}

class LiveEventCurrentRound {
  final int index;
  final LiveRoundPhase phase;
  final LiveEventQuestionSnapshot? question;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;

  const LiveEventCurrentRound({
    this.index = 0,
    this.phase = LiveRoundPhase.lobby,
    this.question,
    this.startedAt,
    this.endsAt,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.skippedCount = 0,
  });

  factory LiveEventCurrentRound.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const LiveEventCurrentRound();
    return LiveEventCurrentRound(
      index: (m['index'] as num?)?.toInt() ?? 0,
      phase: LiveRoundPhase.fromValue(m['phase']?.toString()),
      question: m['question'] is Map<String, dynamic>
          ? LiveEventQuestionSnapshot.fromMap(
              m['question'] as Map<String, dynamic>,
            )
          : null,
      startedAt: _ts(m['startedAt']),
      endsAt: _ts(m['endsAt']),
      correctCount: (m['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (m['wrongCount'] as num?)?.toInt() ?? 0,
      skippedCount: (m['skippedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'index': index,
        'phase': phase.value,
        if (question != null) 'question': question!.toMap(),
        if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
        if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'skippedCount': skippedCount,
      };
}

class LiveEventModel {
  final String id;
  final LiveEventType type;
  final String title;
  final String description;
  final String? bannerUrl;

  /// Coordenador do evento (criador). Avanço de rodadas no cliente.
  final String? hostId;

  final LiveEventStatus status;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final LiveEventGameMode gameMode;
  final int livesPerPlayer;
  final int secondsPerQuestion;
  final int maxParticipants;
  final int questionCount;
  final LiveQuestionSelectionMode selectionMode;
  final LiveEventQuestionFilters filters;
  final List<String> manualQuestionIds;
  final List<LiveEventQuestionSnapshot> questions;
  final List<String> usedQuestionIds;
  final LiveEventRewards rewards;
  final int participantCount;
  final int survivorCount;
  final int eliminatedCount;
  final LiveEventCurrentRound currentRound;
  final LiveEventPushAudience pushAudience;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveEventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.bannerUrl,
    this.hostId,
    required this.status,
    required this.scheduledAt,
    this.startedAt,
    this.endedAt,
    required this.gameMode,
    this.livesPerPlayer = 3,
    this.secondsPerQuestion = 30,
    this.maxParticipants = 5000,
    this.questionCount = 10,
    required this.selectionMode,
    this.filters = const LiveEventQuestionFilters(),
    this.manualQuestionIds = const [],
    this.questions = const [],
    this.usedQuestionIds = const [],
    this.rewards = const LiveEventRewards(),
    this.participantCount = 0,
    this.survivorCount = 0,
    this.eliminatedCount = 0,
    this.currentRound = const LiveEventCurrentRound(),
    this.pushAudience = LiveEventPushAudience.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLive => status == LiveEventStatus.live;
  bool get isEnded => status == LiveEventStatus.ended;
  bool get canJoin =>
      !isEnded &&
      status != LiveEventStatus.cancelled &&
      participantCount < maxParticipants;

  bool get hasHost => hostId != null && hostId!.isNotEmpty;

  bool isHost(String userId) => hasHost && hostId == userId;

  /// Status de exibição no card (inclui "em breve" nas 24h antes).
  LiveEventStatus get displayStatus {
    if (status == LiveEventStatus.live ||
        status == LiveEventStatus.ended ||
        status == LiveEventStatus.cancelled) {
      return status;
    }
    final now = DateTime.now();
    if (scheduledAt.difference(now).inHours <= 24 &&
        scheduledAt.isAfter(now)) {
      return LiveEventStatus.upcoming;
    }
    return LiveEventStatus.scheduled;
  }

  factory LiveEventModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    final questionsRaw = m['questions'];
    final questions = <LiveEventQuestionSnapshot>[];
    if (questionsRaw is List) {
      for (final q in questionsRaw) {
        if (q is Map<String, dynamic>) {
          questions.add(LiveEventQuestionSnapshot.fromMap(q));
        }
      }
    }
    final manualIds = (m['manualQuestionIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return LiveEventModel(
      id: doc.id,
      type: LiveEventType.fromValue(m['type']?.toString()) ??
          LiveEventType.ultimoSobrevivente,
      title: (m['title'] ?? 'Último Sobrevivente').toString(),
      description: (m['description'] ?? '').toString(),
      bannerUrl: m['bannerUrl']?.toString(),
      hostId: m['hostId']?.toString(),
      status: LiveEventStatus.fromValue(m['status']?.toString()),
      scheduledAt: _ts(m['scheduledAt']) ?? DateTime.now(),
      startedAt: _ts(m['startedAt']),
      endedAt: _ts(m['endedAt']),
      gameMode: LiveEventGameMode.fromValue(m['gameMode']?.toString()),
      livesPerPlayer: (m['livesPerPlayer'] as num?)?.toInt() ?? 3,
      secondsPerQuestion: (m['secondsPerQuestion'] as num?)?.toInt() ?? 30,
      maxParticipants: (m['maxParticipants'] as num?)?.toInt() ?? 5000,
      questionCount: (m['questionCount'] as num?)?.toInt() ?? 10,
      selectionMode:
          LiveQuestionSelectionMode.fromValue(m['selectionMode']?.toString()),
      filters: LiveEventQuestionFilters.fromMap(
        m['filters'] as Map<String, dynamic>?,
      ),
      manualQuestionIds: manualIds,
      questions: questions,
      usedQuestionIds: (m['usedQuestionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rewards: LiveEventRewards.fromMap(m['rewards'] as Map<String, dynamic>?),
      participantCount: (m['participantCount'] as num?)?.toInt() ?? 0,
      survivorCount: (m['survivorCount'] as num?)?.toInt() ?? 0,
      eliminatedCount: (m['eliminatedCount'] as num?)?.toInt() ?? 0,
      currentRound: LiveEventCurrentRound.fromMap(
        m['currentRound'] as Map<String, dynamic>?,
      ),
      pushAudience: LiveEventPushAudience.fromValue(
        m['pushAudience']?.toString(),
      ),
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      updatedAt: _ts(m['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'title': title,
        'description': description,
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
        if (hostId != null && hostId!.isNotEmpty) 'hostId': hostId,
        'status': status.value,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
        if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
        'gameMode': gameMode.value,
        'livesPerPlayer': livesPerPlayer,
        'secondsPerQuestion': secondsPerQuestion,
        'maxParticipants': maxParticipants,
        'questionCount': questionCount,
        'selectionMode': selectionMode.value,
        'filters': filters.toMap(),
        'manualQuestionIds': manualQuestionIds,
        'questions': questions.map((q) => q.toMap()).toList(),
        'rewards': rewards.toMap(),
        'pushAudience': pushAudience.value,
        'participantCount': participantCount,
        'survivorCount': survivorCount,
        'eliminatedCount': eliminatedCount,
        'currentRound': currentRound.toMap(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

class LiveEventParticipant {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final ParticipantStatus status;
  final int livesRemaining;
  final int correctAnswers;
  final int totalResponseTimeMs;
  final int? eliminatedAtRound;
  final int score;
  final int? finalRank;
  final int xpEarned;
  final int? lastAnswerRound;
  final String? lastAnswerAlternativeId;
  final bool? lastAnswerCorrect;
  final DateTime? joinedAt;

  const LiveEventParticipant({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.status,
    required this.livesRemaining,
    required this.correctAnswers,
    required this.totalResponseTimeMs,
    this.eliminatedAtRound,
    required this.score,
    this.finalRank,
    this.xpEarned = 0,
    this.lastAnswerRound,
    this.lastAnswerAlternativeId,
    this.lastAnswerCorrect,
    this.joinedAt,
  });

  bool get isActive => status == ParticipantStatus.active;
  bool get isEliminated => status == ParticipantStatus.eliminated;

  factory LiveEventParticipant.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return LiveEventParticipant(
      userId: doc.id,
      displayName: (m['displayName'] ?? 'Participante').toString(),
      photoUrl: m['photoUrl']?.toString(),
      status: ParticipantStatus.fromValue(m['status']?.toString()),
      livesRemaining: (m['livesRemaining'] as num?)?.toInt() ?? 0,
      correctAnswers: (m['correctAnswers'] as num?)?.toInt() ?? 0,
      totalResponseTimeMs: (m['totalResponseTimeMs'] as num?)?.toInt() ?? 0,
      eliminatedAtRound: (m['eliminatedAtRound'] as num?)?.toInt(),
      score: (m['score'] as num?)?.toInt() ?? 0,
      finalRank: (m['finalRank'] as num?)?.toInt(),
      xpEarned: (m['xpEarned'] as num?)?.toInt() ?? 0,
      lastAnswerRound: (m['lastAnswerRound'] as num?)?.toInt(),
      lastAnswerAlternativeId: m['lastAnswerAlternativeId']?.toString(),
      lastAnswerCorrect: m['lastAnswerCorrect'] as bool?,
      joinedAt: _ts(m['joinedAt']),
    );
  }
}

class LiveEventRankingEntry {
  final String userId;
  final String displayName;
  final int rank;
  final int score;
  final int correctAnswers;
  final int avgResponseMs;
  final ParticipantStatus status;

  const LiveEventRankingEntry({
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.score,
    required this.correctAnswers,
    required this.avgResponseMs,
    required this.status,
  });
}

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  return null;
}
