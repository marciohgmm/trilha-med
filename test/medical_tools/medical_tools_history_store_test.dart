import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/medical_tool_history_entry.dart';
import 'package:flutter_application_1/services/medical_tools/medical_tools_history_store.dart';

void main() {
  group('MedicalToolsHistoryStore', () {
    late MedicalToolsHistoryStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = MedicalToolsHistoryStore(prefs: prefs);
    });

    MedicalToolHistoryEntry entry(String id, String toolId) {
      return MedicalToolHistoryEntry(
        id: id,
        toolId: toolId,
        title: 'Test',
        summary: 'Summary $id',
        calculatedAt: DateTime(2026, 1, 1).add(Duration(minutes: int.parse(id))),
      );
    }

    test('append e loadForTool filtram por ferramenta', () async {
      await store.append(entry('1', 'adult_bmi'));
      await store.append(entry('2', 'burns_rule_of_nine'));
      await store.append(entry('3', 'adult_bmi'));

      final bmi = await store.loadForTool('adult_bmi');
      expect(bmi.length, 2);
      expect(bmi.every((e) => e.toolId == 'adult_bmi'), isTrue);
    });

    test('mantém no máximo 20 entradas globais', () async {
      for (var i = 0; i < 25; i++) {
        await store.append(entry('$i', 'adult_bmi'));
      }
      final all = await store.loadAll();
      expect(all.length, MedicalToolsHistoryStore.maxEntries);
    });

    test('clear remove histórico', () async {
      await store.append(entry('1', 'adult_bmi'));
      await store.clear();
      expect(await store.loadAll(), isEmpty);
    });
  });
}
