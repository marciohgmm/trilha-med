import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/questao_model.dart';
import 'package:flutter_application_1/services/revalida_official/revalida_question_pool_cache.dart';

QuestaoModel _sample(String id, String materia) {
  return QuestaoModel(
    id: id,
    temaId: 't',
    temaSlug: 't',
    materiaId: 'm',
    materia: materia,
    tema: 'T',
    subtema: 'S',
    flashcardId: null,
    enunciado: 'Q',
    alternativas: const [QuestaoAlternativa(id: 'a', texto: 'A')],
    corretaId: 'a',
    explicacaoGeral: '',
    explicacaoCorreta: '',
    explicacoesErradas: const {},
    justificativasPorAlternativa: const {},
    dificuldade: 'media',
    status: 'ativa',
    tags: const [],
    ativo: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    ordem: 0,
  );
}

void main() {
  group('RevalidaQuestionPoolCache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RevalidaPoolCacheConfig.ttl = const Duration(minutes: 30);
    });

    test('salva e recupera pool válido', () async {
      final cache = RevalidaQuestionPoolCache();
      final entry = RevalidaCachedQuestionPool(
        poolByMateria: {
          'Clínica': [_sample('1', 'Clínica')],
        },
        cachedAt: DateTime.now(),
        materiaNames: const ['Clínica'],
      );

      await cache.save(entry);
      final loaded = await cache.loadValid();
      expect(loaded, isNotNull);
      expect(loaded!.poolByMateria['Clínica']!.length, 1);
    });

    test('invalida após TTL expirado', () async {
      RevalidaPoolCacheConfig.ttl = Duration.zero;
      final cache = RevalidaQuestionPoolCache();
      await cache.save(
        RevalidaCachedQuestionPool(
          poolByMateria: {'M': [_sample('1', 'M')]},
          cachedAt: DateTime.now().subtract(const Duration(minutes: 1)),
          materiaNames: const ['M'],
        ),
      );

      expect(await cache.loadValid(), isNull);
    });

    test('clear remove entrada', () async {
      final cache = RevalidaQuestionPoolCache();
      await cache.save(
        RevalidaCachedQuestionPool(
          poolByMateria: {'M': [_sample('1', 'M')]},
          cachedAt: DateTime.now(),
          materiaNames: const ['M'],
        ),
      );
      await cache.clear();
      expect(await cache.loadValid(), isNull);
    });
  });
}
