import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/questao_model.dart';
import '../../models/revalida_simulation_model.dart';
import '../../domain/revalida_official/revalida_official_config.dart';
import '../../domain/revalida_official/revalida_performance_calculator.dart';
import '../questao_service.dart';
import 'revalida_official_exam_builder.dart';
import 'revalida_simulation_repository.dart';

/// Rascunho local do simulado Revalida Oficial em andamento.
class RevalidaOfficialDraft {
  const RevalidaOfficialDraft({
    required this.userId,
    required this.questaoIds,
    required this.selecoes,
    required this.paginaAtual,
    required this.startedAt,
    required this.remainingSeconds,
    required this.salvoEm,
  });

  final String userId;
  final List<String> questaoIds;
  final Map<String, String> selecoes;
  final int paginaAtual;
  final DateTime startedAt;
  final int remainingSeconds;
  final DateTime salvoEm;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'questaoIds': questaoIds,
        'selecoes': selecoes,
        'paginaAtual': paginaAtual,
        'startedAt': startedAt.toIso8601String(),
        'remainingSeconds': remainingSeconds,
        'salvoEm': salvoEm.toIso8601String(),
      };

  factory RevalidaOfficialDraft.fromJson(Map<String, dynamic> json) {
    final selRaw = json['selecoes'];
    final selecoes = <String, String>{};
    if (selRaw is Map) {
      selRaw.forEach((k, v) => selecoes[k.toString()] = v.toString());
    }
    return RevalidaOfficialDraft(
      userId: json['userId']?.toString() ?? '',
      questaoIds: (json['questaoIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      selecoes: selecoes,
      paginaAtual: (json['paginaAtual'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      remainingSeconds:
          (json['remainingSeconds'] as num?)?.toInt() ??
              RevalidaOfficialConfig.defaultDurationSeconds,
      salvoEm: DateTime.tryParse(json['salvoEm']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RevalidaOfficialSessionStore {
  RevalidaOfficialSessionStore._();
  static final RevalidaOfficialSessionStore instance =
      RevalidaOfficialSessionStore._();

  static const _key = 'revalida_official_draft_v1';

  Future<void> save(RevalidaOfficialDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  Future<RevalidaOfficialDraft?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final draft = RevalidaOfficialDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (draft.userId != userId) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  bool compatible(RevalidaOfficialDraft draft, List<String> questaoIds) {
    if (draft.questaoIds.length != questaoIds.length) return false;
    return Set<String>.from(draft.questaoIds).containsAll(questaoIds);
  }
}

/// Montagem e entrega do Simulado Revalida Oficial.
class RevalidaOfficialService {
  RevalidaOfficialService({
    FirebaseFirestore? db,
    RevalidaSimulationRepository? repository,
    RevalidaPerformanceCalculator? calculator,
    RevalidaOfficialExamBuilder? examBuilder,
  })  : _repository = repository ?? RevalidaSimulationRepository(),
        _calculator = calculator ?? RevalidaPerformanceCalculator(),
        _examBuilder = examBuilder ?? RevalidaOfficialExamBuilder(db: db);

  final RevalidaSimulationRepository _repository;
  final RevalidaPerformanceCalculator _calculator;
  final RevalidaOfficialExamBuilder _examBuilder;

  RevalidaSimulationRepository get repository => _repository;

  Future<List<QuestaoModel>> montarProvaOficial({
    int questionCount = RevalidaOfficialConfig.questionCount,
  }) async {
    final result = await _examBuilder.build(questionCount: questionCount);
    return result.questoes;
  }

  Future<RevalidaSimulationRecord> entregarProva({
    required String uid,
    required List<QuestaoModel> questoes,
    required Map<String, String> selecoes,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    final performance = _calculator.calculate(
      questoes: questoes,
      selectedAlternativaByQuestaoId: selecoes,
      durationSeconds: durationSeconds,
    );

    final questaoService = QuestaoService();
    for (final q in questoes) {
      final selected = selecoes[q.id];
      if (selected == null || selected.isEmpty) continue;
      final acertou = selected == q.corretaId;
      await questaoService.registrarResposta(
        userId: uid,
        questao: q,
        alternativaSelecionadaId: selected,
        acertou: acertou,
      );
    }

    final finishedAt = DateTime.now();
    final record = RevalidaSimulationRecord(
      id: '',
      uid: uid,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationSeconds: durationSeconds,
      score: performance.scorePercent,
      totalQuestions: performance.totalQuestions,
      correctAnswers: performance.correctAnswers,
      wrongAnswers: performance.wrongAnswers,
      unanswered: performance.unanswered,
      subjectBreakdown: performance.subjectBreakdown,
      subtopicBreakdown: performance.subtopicBreakdown,
      questaoIds: questoes.map((q) => q.id).toList(),
      respostas: Map<String, String>.from(selecoes),
    );

    final id = await _repository.save(record);
    return RevalidaSimulationRecord(
      id: id,
      uid: record.uid,
      startedAt: record.startedAt,
      finishedAt: record.finishedAt,
      durationSeconds: record.durationSeconds,
      score: record.score,
      totalQuestions: record.totalQuestions,
      correctAnswers: record.correctAnswers,
      wrongAnswers: record.wrongAnswers,
      unanswered: record.unanswered,
      subjectBreakdown: record.subjectBreakdown,
      subtopicBreakdown: record.subtopicBreakdown,
      questaoIds: record.questaoIds,
      respostas: record.respostas,
    );
  }
}
