import 'package:flutter_application_1/core/app_check/app_check_config.dart';
import 'package:flutter_application_1/core/app_check/app_check_web_runtime.dart';
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

    test('resolveWebProvider em VM de teste não é web — lança', () {
      final config = AppCheckConfig.fromEnvironment();
      final runtime = AppCheckWebRuntimeKeys.resolve(config);
      expect(
        () => config.resolveWebProvider(useDebug: false, runtime: runtime),
        throwsStateError,
      );
    });

    test('produção segura não lança em test harness', () {
      final config = AppCheckConfig.fromEnvironment();
      expect(() => config.assertProductionSafe(), returnsNormally);
    });

    test('edgeDebugRunHint inclui RECAPTCHA_V3_SITE_KEY', () {
      expect(
        AppCheckWebRuntimeKeys.edgeDebugRunHint(),
        contains('RECAPTCHA_V3_SITE_KEY'),
      );
      expect(
        AppCheckWebRuntimeKeys.edgeDebugRunHint(),
        contains('APP_CHECK_DEBUG=true'),
      );
    });
  });
}
