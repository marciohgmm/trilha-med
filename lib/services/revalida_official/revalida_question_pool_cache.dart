import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/revalida_official/revalida_official_config.dart';
import '../../models/questao_model.dart';

/// Configuração do cache de pools (TTL configurável).
abstract final class RevalidaPoolCacheConfig {
  static const cacheKey = 'revalida_question_pool_cache_v1';
  static Duration ttl = RevalidaOfficialConfig.poolCacheTtl;
}

/// Pool de questões por matéria em cache.
class RevalidaCachedQuestionPool {
  const RevalidaCachedQuestionPool({
    required this.poolByMateria,
    required this.cachedAt,
    required this.materiaNames,
  });

  final Map<String, List<QuestaoModel>> poolByMateria;
  final DateTime cachedAt;
  final List<String> materiaNames;

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > RevalidaPoolCacheConfig.ttl;

  Map<String, dynamic> toJson() => {
        'cachedAt': cachedAt.toIso8601String(),
        'materiaNames': materiaNames,
        'pools': poolByMateria.map(
          (materia, list) => MapEntry(
            materia,
            list
                .map(
                  (q) => {'id': q.id, 'data': _questaoToCacheJson(q)},
                )
                .toList(),
          ),
        ),
      };

  static Map<String, dynamic> _questaoToCacheJson(QuestaoModel q) {
    return {
      'temaId': q.temaId,
      'temaSlug': q.temaSlug,
      'materiaId': q.materiaId,
      'materia': q.materia,
      'tema': q.tema,
      'subtema': q.subtema,
      'flashcardId': q.flashcardId,
      'enunciado': q.enunciado,
      'alternativas': q.alternativas.map((a) => a.toMap()).toList(),
      'corretaId': q.corretaId,
      'explicacao': q.explicacaoGeral,
      'explicacaoCorreta': q.explicacaoCorreta,
      'explicacoesErradas': q.explicacoesErradas,
      'justificativasPorAlternativa': q.justificativasPorAlternativa,
      'dificuldade': q.dificuldade,
      'status': q.status,
      'tags': q.tags,
      'ativo': q.ativo,
      'createdAt': q.createdAt.toIso8601String(),
      'updatedAt': q.updatedAt.toIso8601String(),
      'ordem': q.ordem,
    };
  }

  factory RevalidaCachedQuestionPool.fromJson(Map<String, dynamic> json) {
    final poolsRaw = json['pools'] as Map? ?? {};
    final poolByMateria = <String, List<QuestaoModel>>{};
    poolsRaw.forEach((materia, list) {
      if (list is! List) return;
      poolByMateria[materia.toString()] = list.map((item) {
        final map = item as Map;
        final id = map['id']?.toString() ?? '';
        final data = Map<String, dynamic>.from(map['data'] as Map? ?? {});
        return QuestaoModel.fromMap(id, data);
      }).toList();
    });

    return RevalidaCachedQuestionPool(
      poolByMateria: poolByMateria,
      cachedAt: DateTime.tryParse(json['cachedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      materiaNames: (json['materiaNames'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          poolByMateria.keys.toList(),
    );
  }
}

/// Cache local temporário — reutilizado entre simulados dentro do TTL.
class RevalidaQuestionPoolCache {
  RevalidaQuestionPoolCache({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<RevalidaCachedQuestionPool?> loadValid() async {
    final prefs = await _storage;
    final raw = prefs.getString(RevalidaPoolCacheConfig.cacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final entry = RevalidaCachedQuestionPool.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (entry.isExpired) {
        await clear();
        return null;
      }
      if (entry.poolByMateria.isEmpty) return null;
      return entry;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(RevalidaCachedQuestionPool entry) async {
    final prefs = await _storage;
    await prefs.setString(
      RevalidaPoolCacheConfig.cacheKey,
      jsonEncode(entry.toJson()),
    );
  }

  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(RevalidaPoolCacheConfig.cacheKey);
  }
}
