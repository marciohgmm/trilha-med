import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/revalida_official/revalida_exceptions.dart';
import '../../domain/revalida_official/revalida_official_config.dart';
import '../../domain/revalida_official/revalida_performance_calculator.dart';
import '../../domain/revalida_official/revalida_simulator_build_metrics.dart';
import '../../models/flashcard_materia_stat.dart';
import '../../models/questao_model.dart';
import '../questao_materia_stats_service.dart';
import '../questao_service.dart';
import 'revalida_question_pool_cache.dart';

/// Resultado da montagem com métricas internas.
class RevalidaExamBuildResult {
  const RevalidaExamBuildResult({
    required this.questoes,
    required this.metrics,
  });

  final List<QuestaoModel> questoes;
  final RevalidaSimulatorBuildMetrics metrics;
}

/// Monta prova oficial sem scan completo de `questoes`.
class RevalidaOfficialExamBuilder {
  RevalidaOfficialExamBuilder({
    FirebaseFirestore? db,
    QuestaoMateriaStatsService? materiaStats,
    RevalidaQuestionPoolCache? cache,
  })  : _db = db ?? FirebaseFirestore.instance,
        _materiaStats = materiaStats ?? QuestaoMateriaStatsService.instance,
        _cache = cache ?? RevalidaQuestionPoolCache();

  final FirebaseFirestore _db;
  final QuestaoMateriaStatsService _materiaStats;
  final RevalidaQuestionPoolCache _cache;

  Future<RevalidaExamBuildResult> build({
    int questionCount = RevalidaOfficialConfig.questionCount,
  }) async {
    final stopwatch = Stopwatch()..start();
    final metrics = RevalidaSimulatorBuildMetrics();

    final cached = await _cache.loadValid();
    if (cached != null) {
      metrics.cacheHit = true;
      metrics.materiaCount = cached.materiaNames.length;
      final selected = _selectFromPool(
        poolByMateria: _clonePool(cached.poolByMateria),
        questionCount: questionCount,
      );
      metrics.documentsEvaluated = cached.poolByMateria.values
          .fold<int>(0, (acc, list) => acc + list.length);
      metrics.documentsSelected = selected.length;
      metrics.buildDurationMs = stopwatch.elapsedMilliseconds;
      RevalidaSimulatorBuildLogger.log(metrics);
      return RevalidaExamBuildResult(questoes: selected, metrics: metrics);
    }

    final stats = await _materiaStats.fetchMateriaStats();
    metrics.firestoreReads += stats.length;
    metrics.materiaCount = stats.length;

    if (stats.isEmpty) {
      throw RevalidaInsufficientQuestionsException(
        available: 0,
        required: questionCount,
      );
    }

    final materias = stats.map((s) => s.name).toList();
    final quotas = computeBalancedMateriaQuotas(
      materias: materias,
      total: questionCount,
    );

    final poolByMateria = <String, List<QuestaoModel>>{};
    final fetchedIds = <String>{};

    await _fetchPoolsPrimary(
      stats: stats,
      quotas: quotas,
      poolByMateria: poolByMateria,
      fetchedIds: fetchedIds,
      metrics: metrics,
    );

    var selected = _selectFromPool(
      poolByMateria: poolByMateria,
      questionCount: questionCount,
    );

    if (selected.length < questionCount) {
      await _fetchPoolsFallback(
        stats: stats,
        quotas: quotas,
        poolByMateria: poolByMateria,
        fetchedIds: fetchedIds,
        metrics: metrics,
        needed: questionCount,
      );
      selected = _selectFromPool(
        poolByMateria: poolByMateria,
        questionCount: questionCount,
      );
    }

    if (selected.length < questionCount) {
      metrics.buildDurationMs = stopwatch.elapsedMilliseconds;
      RevalidaSimulatorBuildLogger.log(metrics);
      throw RevalidaInsufficientQuestionsException(
        available: selected.length,
        required: questionCount,
      );
    }

    await _cache.save(
      RevalidaCachedQuestionPool(
        poolByMateria: poolByMateria,
        cachedAt: DateTime.now(),
        materiaNames: materias,
      ),
    );

    metrics.documentsSelected = selected.length;
    metrics.buildDurationMs = stopwatch.elapsedMilliseconds;
    RevalidaSimulatorBuildLogger.log(metrics);

    return RevalidaExamBuildResult(questoes: selected, metrics: metrics);
  }

  Future<void> _fetchPoolsPrimary({
    required List<FlashcardMateriaStat> stats,
    required Map<String, int> quotas,
    required Map<String, List<QuestaoModel>> poolByMateria,
    required Set<String> fetchedIds,
    required RevalidaSimulatorBuildMetrics metrics,
  }) async {
    for (final stat in stats) {
      final materia = stat.name;
      final quota = quotas[materia] ?? 0;
      if (quota <= 0) continue;

      final limit = computeRevalidaFetchLimit(
        quota: quota,
        materiaTotal: stat.total,
      );
      if (limit <= 0) continue;

      final snap = await _db
          .collection(QuestaoService.collectionQuestoes)
          .where('materia', isEqualTo: materia)
          .limit(limit)
          .get();

      metrics.firestoreReads += snap.docs.length;

      final pool = <QuestaoModel>[];
      for (final doc in snap.docs) {
        metrics.documentsEvaluated++;
        fetchedIds.add(doc.id);
        final q = QuestaoModel.fromMap(doc.id, doc.data());
        if (!q.disponivelParaEstudo) continue;
        pool.add(q);
      }
      pool.shuffle(Random());
      poolByMateria[materia] = pool;
    }
  }

  Future<void> _fetchPoolsFallback({
    required List<FlashcardMateriaStat> stats,
    required Map<String, int> quotas,
    required Map<String, List<QuestaoModel>> poolByMateria,
    required Set<String> fetchedIds,
    required RevalidaSimulatorBuildMetrics metrics,
    required int needed,
  }) async {
    for (final stat in stats) {
      final current = poolByMateria[stat.name]?.length ?? 0;
      if (current >= stat.total) continue;

      final snap = await _db
          .collection(QuestaoService.collectionQuestoes)
          .where('materia', isEqualTo: stat.name)
          .limit(stat.total)
          .get();

      metrics.firestoreReads += snap.docs.length;

      final pool = poolByMateria.putIfAbsent(stat.name, () => []);
      for (final doc in snap.docs) {
        if (fetchedIds.contains(doc.id)) continue;
        metrics.documentsEvaluated++;
        fetchedIds.add(doc.id);
        final q = QuestaoModel.fromMap(doc.id, doc.data());
        if (!q.disponivelParaEstudo) continue;
        pool.add(q);
      }
      pool.shuffle(Random());

      final selected = _selectFromPool(
        poolByMateria: poolByMateria,
        questionCount: needed,
      );
      if (selected.length >= needed) return;
    }
  }

  List<QuestaoModel> _selectFromPool({
    required Map<String, List<QuestaoModel>> poolByMateria,
    required int questionCount,
  }) {
    final shuffledPools = poolByMateria.map(
      (k, v) => MapEntry(k, List<QuestaoModel>.from(v)..shuffle(Random())),
    );

    final selected = selectBalancedQuestions(
      poolByMateria: shuffledPools,
      total: questionCount,
    );
    selected.shuffle(Random());
    return selected;
  }

  Map<String, List<QuestaoModel>> _clonePool(
    Map<String, List<QuestaoModel>> source,
  ) {
    return source.map(
      (k, v) => MapEntry(k, List<QuestaoModel>.from(v)),
    );
  }
}
