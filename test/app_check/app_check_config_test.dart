import 'package:flutter_application_1/core/app_check/app_check_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCheckConfig', () {
    test('fromEnvironment retorna instância válida', () {
      final config = AppCheckConfig.fromEnvironment();
      expect(config, isA<AppCheckConfig>());
    });

    test('debug define documentado', () {
      expect(AppCheckConfig.debugDefine, isA<bool>());
    });

    test('resolveWebProvider em VM de teste não é web — retorna null', () {
      final config = AppCheckConfig.fromEnvironment();
      expect(config.resolveWebProvider(), isNull);
    });

    test('produção segura não lança em test harness', () {
      final config = AppCheckConfig.fromEnvironment();
      expect(() => config.assertProductionSafe(), returnsNormally);
    });
  });
}
