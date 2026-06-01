import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/simulado_models.dart';

/// Rascunho local do simulado em andamento (recuperação / sincronização offline).
class SimuladoRascunho {
  final String userId;
  final List<String> questaoIds;
  final Map<String, bool> respostas;
  final int paginaAtual;
  final int segundosDecorridos;
  final SimuladoFiltros filtros;
  final DateTime salvoEm;

  const SimuladoRascunho({
    required this.userId,
    required this.questaoIds,
    required this.respostas,
    required this.paginaAtual,
    required this.segundosDecorridos,
    required this.filtros,
    required this.salvoEm,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'questaoIds': questaoIds,
        'respostas': respostas.map((k, v) => MapEntry(k, v)),
        'paginaAtual': paginaAtual,
        'segundosDecorridos': segundosDecorridos,
        'filtros': filtros.toMap(),
        'salvoEm': salvoEm.toIso8601String(),
      };

  factory SimuladoRascunho.fromJson(Map<String, dynamic> json) {
    final respostasRaw = json['respostas'];
    final respostas = <String, bool>{};
    if (respostasRaw is Map) {
      respostasRaw.forEach((k, v) {
        respostas[k.toString()] = v == true;
      });
    }
    return SimuladoRascunho(
      userId: json['userId']?.toString() ?? '',
      questaoIds: (json['questaoIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      respostas: respostas,
      paginaAtual: (json['paginaAtual'] as num?)?.toInt() ?? 0,
      segundosDecorridos: (json['segundosDecorridos'] as num?)?.toInt() ?? 0,
      filtros: SimuladoFiltros.fromMap(
        Map<String, dynamic>.from(json['filtros'] as Map? ?? {}),
      ),
      salvoEm: DateTime.tryParse(json['salvoEm']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Persistência local do simulado (SharedPreferences).
class SimuladoSessionStore {
  SimuladoSessionStore._();
  static final SimuladoSessionStore instance = SimuladoSessionStore._();

  static const _keyRascunho = 'simulado_rascunho_v1';

  Future<void> salvarRascunho(SimuladoRascunho rascunho) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRascunho, jsonEncode(rascunho.toJson()));
  }

  Future<SimuladoRascunho?> carregarRascunho(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRascunho);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final draft = SimuladoRascunho.fromJson(json);
      if (draft.userId != userId) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> limparRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRascunho);
  }

  /// Verifica se o rascunho corresponde à mesma sessão (mesmas questões).
  bool rascunhoCompativel(
    SimuladoRascunho rascunho,
    List<String> questaoIdsAtuais,
  ) {
    if (rascunho.questaoIds.length != questaoIdsAtuais.length) return false;
    final a = Set<String>.from(rascunho.questaoIds);
    final b = Set<String>.from(questaoIdsAtuais);
    return a.containsAll(b);
  }
}
