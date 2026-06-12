import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/medical_tools/burns_rule_of_nine.dart';

void main() {
  group('BurnsRuleOfNineSelection', () {
    test('inicia em 0%', () {
      const s = BurnsRuleOfNineSelection();
      expect(s.totalPercent, 0);
      expect(s.isEmpty, isTrue);
    });

    test('soma regiões sem duplicar', () {
      var s = const BurnsRuleOfNineSelection();
      s = s.toggle(BurnRegionId.headAnterior);
      s = s.toggle(BurnRegionId.headAnterior);
      expect(s.totalPercent, 0);
    });

    test('exemplo didático totaliza 18%', () {
      final s = const BurnsRuleOfNineSelection().applyExample();
      expect(s.totalPercent, 18);
      expect(s.selected.length, 3);
    });

    test('todas as regiões somam 100%', () {
      var s = const BurnsRuleOfNineSelection();
      for (final r in adultBurnRegions) {
        s = s.toggle(r.id);
      }
      expect(s.totalPercent, 100);
    });

    test('não ultrapassa 100% ao adicionar', () {
      var s = const BurnsRuleOfNineSelection();
      for (final r in adultBurnRegions) {
        if (canAddRegion(s, r.id)) {
          s = s.toggle(r.id);
        }
      }
      expect(s.totalPercent, lessThanOrEqualTo(100));
    });
  });

  group('buildExampleSumLines', () {
    test('inclui total 18%', () {
      final lines = buildExampleSumLines();
      expect(lines.last, 'Total = 18%');
    });
  });
}
