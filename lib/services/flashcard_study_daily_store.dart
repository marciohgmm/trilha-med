import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local da **sessão de estudo do dia** (por usuário + matéria + subtema).
class FlashcardStudyDailyStore {
  FlashcardStudyDailyStore._();

  static String todayYmdLocal() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static String prefsKey(String userId, String materia, String subtema) {
    final h = Object.hash(userId, materia, subtema);
    return 'fc_study_sess_v2_${userId}_$h';
  }

  /// Chave legada (incluía tema) — leitura de compatibilidade.
  static String _prefsKeyLegacy(
    String userId,
    String materia,
    String tema,
    String subtema,
  ) {
    final h = Object.hash(userId, materia, tema, subtema);
    return 'fc_study_sess_v1_${userId}_$h';
  }

  static Future<FlashcardStudySessionSnapshot?> load({
    required String userId,
    required String materia,
    required String subtema,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keysToTry = <String>[
      prefsKey(userId, materia, subtema),
      _prefsKeyLegacy(userId, materia, '', subtema),
    ];

    for (final key in keysToTry) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final snap = FlashcardStudySessionSnapshot.fromJson(map);
        if (snap.dateYmd != todayYmdLocal()) continue;
        if (snap.materia != materia || snap.subtema != subtema) continue;
        return snap;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<void> save({
    required String userId,
    required String materia,
    required String subtema,
    required FlashcardStudySessionSnapshot snapshot,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefsKey(userId, materia, subtema);
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
  }

  static Future<void> clear({
    required String userId,
    required String materia,
    required String subtema,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey(userId, materia, subtema));
    await prefs.remove(_prefsKeyLegacy(userId, materia, '', subtema));
  }
}

/// Estado serializável da sessão na tela de estudo.
class FlashcardStudySessionSnapshot {
  final String dateYmd;
  final String materia;
  final String subtema;

  final List<String> marcadosFaceis;
  final List<String> fila;
  final List<FlashcardRetornoSnapshot> retornos;
  final String? cardAtualId;
  final Map<String, int> aparicoes;
  final List<String> vistos;
  final int totalCardsSessao;
  final bool assuntoConcluido;
  final bool sessaoEsgotada;

  const FlashcardStudySessionSnapshot({
    required this.dateYmd,
    required this.materia,
    required this.subtema,
    required this.marcadosFaceis,
    required this.fila,
    required this.retornos,
    required this.cardAtualId,
    required this.aparicoes,
    required this.vistos,
    required this.totalCardsSessao,
    required this.assuntoConcluido,
    required this.sessaoEsgotada,
  });

  Map<String, dynamic> toJson() => {
        'dateYmd': dateYmd,
        'materia': materia,
        'subtema': subtema,
        'marcadosFaceis': marcadosFaceis,
        'fila': fila,
        'retornos': retornos.map((e) => e.toJson()).toList(),
        'cardAtualId': cardAtualId,
        'aparicoes': aparicoes,
        'vistos': vistos,
        'totalCardsSessao': totalCardsSessao,
        'assuntoConcluido': assuntoConcluido,
        'sessaoEsgotada': sessaoEsgotada,
      };

  factory FlashcardStudySessionSnapshot.fromJson(Map<String, dynamic> j) {
    final retRaw = j['retornos'];
    final retornos = <FlashcardRetornoSnapshot>[];
    if (retRaw is List) {
      for (final e in retRaw) {
        if (e is Map<String, dynamic>) {
          retornos.add(FlashcardRetornoSnapshot.fromJson(e));
        } else if (e is Map) {
          retornos.add(
              FlashcardRetornoSnapshot.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final ap = <String, int>{};
    final apRaw = j['aparicoes'];
    if (apRaw is Map) {
      apRaw.forEach((k, v) {
        if (k is String && v is int) ap[k] = v;
        if (k is String && v is num) ap[k] = v.toInt();
      });
    }
    return FlashcardStudySessionSnapshot(
      dateYmd: (j['dateYmd'] ?? '').toString(),
      materia: (j['materia'] ?? '').toString(),
      subtema: (j['subtema'] ?? '').toString(),
      marcadosFaceis:
          (j['marcadosFaceis'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      fila: (j['fila'] as List?)?.map((e) => e.toString()).toList() ?? [],
      retornos: retornos,
      cardAtualId: j['cardAtualId']?.toString(),
      aparicoes: ap,
      vistos: (j['vistos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      totalCardsSessao: (j['totalCardsSessao'] is int)
          ? j['totalCardsSessao'] as int
          : int.tryParse('${j['totalCardsSessao']}') ?? 0,
      assuntoConcluido: j['assuntoConcluido'] == true,
      sessaoEsgotada: j['sessaoEsgotada'] == true,
    );
  }
}

class FlashcardRetornoSnapshot {
  final String cardId;
  final int faltam;

  const FlashcardRetornoSnapshot({required this.cardId, required this.faltam});

  Map<String, dynamic> toJson() => {'cardId': cardId, 'faltam': faltam};

  factory FlashcardRetornoSnapshot.fromJson(Map<String, dynamic> j) {
    return FlashcardRetornoSnapshot(
      cardId: (j['cardId'] ?? '').toString(),
      faltam: (j['faltam'] is int)
          ? j['faltam'] as int
          : int.tryParse('${j['faltam']}') ?? 0,
    );
  }
}
