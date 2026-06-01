import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/revalida_official/revalida_official_service.dart';

void main() {
  group('RevalidaOfficialSessionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('salva e carrega rascunho', () async {
      final store = RevalidaOfficialSessionStore.instance;
      final draft = RevalidaOfficialDraft(
        userId: 'user1',
        questaoIds: const ['q1', 'q2'],
        selecoes: const {'q1': 'a'},
        paginaAtual: 1,
        startedAt: DateTime(2026, 5, 1),
        remainingSeconds: 7200,
        salvoEm: DateTime(2026, 5, 1),
      );

      await store.save(draft);
      final loaded = await store.load('user1');
      expect(loaded, isNotNull);
      expect(loaded!.selecoes['q1'], 'a');
      expect(loaded.paginaAtual, 1);
    });

    test('clear remove rascunho', () async {
      final store = RevalidaOfficialSessionStore.instance;
      await store.save(
        RevalidaOfficialDraft(
          userId: 'user1',
          questaoIds: const ['q1'],
          selecoes: const {},
          paginaAtual: 0,
          startedAt: DateTime.now(),
          remainingSeconds: 100,
          salvoEm: DateTime.now(),
        ),
      );
      await store.clear();
      expect(await store.load('user1'), isNull);
    });

    test('compatible verifica mesmas questões', () {
      final store = RevalidaOfficialSessionStore.instance;
      final draft = RevalidaOfficialDraft(
        userId: 'u',
        questaoIds: const ['a', 'b'],
        selecoes: const {},
        paginaAtual: 0,
        startedAt: DateTime.now(),
        remainingSeconds: 100,
        salvoEm: DateTime.now(),
      );
      expect(store.compatible(draft, const ['a', 'b']), isTrue);
      expect(store.compatible(draft, const ['a', 'c']), isFalse);
    });
  });
}
