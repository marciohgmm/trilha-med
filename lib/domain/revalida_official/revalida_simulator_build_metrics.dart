import 'package:flutter/foundation.dart';

import 'revalida_official_config.dart';

/// Métricas internas da montagem da prova (não expostas ao usuário).
class RevalidaSimulatorBuildMetrics {
  RevalidaSimulatorBuildMetrics({
    this.buildDurationMs = 0,
    this.firestoreReads = 0,
    this.documentsEvaluated = 0,
    this.documentsSelected = 0,
    this.cacheHit = false,
    this.materiaCount = 0,
  });

  int buildDurationMs;
  int firestoreReads;
  int documentsEvaluated;
  int documentsSelected;
  bool cacheHit;
  int materiaCount;

  Map<String, dynamic> toLogMap() => {
        'durationMs': buildDurationMs,
        'reads': firestoreReads,
        'evaluated': documentsEvaluated,
        'selected': documentsSelected,
        'cacheHit': cacheHit,
        'materias': materiaCount,
      };
}

/// Log interno — evento `revalida_simulator.build`.
abstract final class RevalidaSimulatorBuildLogger {
  static void log(RevalidaSimulatorBuildMetrics metrics) {
    debugPrint(
      '[revalida_simulator.build] ${metrics.toLogMap()}',
    );
  }
}

/// Limites de fetch por matéria (sem alterar regra de negócio da seleção).
int computeRevalidaFetchLimit({
  required int quota,
  required int materiaTotal,
  int multiplier = RevalidaOfficialConfig.fetchLimitMultiplier,
  int minBuffer = RevalidaOfficialConfig.fetchLimitMinBuffer,
}) {
  if (quota <= 0 || materiaTotal <= 0) return 0;
  final target = quota * multiplier + minBuffer;
  return target > materiaTotal ? materiaTotal : target;
}
