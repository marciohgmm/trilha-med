import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Configuração de App Check via `--dart-define` (sem ativar debug em release).
class AppCheckConfig {
  const AppCheckConfig({
    required this.useDebugProvider,
    this.recaptchaEnterpriseSiteKey,
    this.recaptchaV3SiteKey,
    this.useFirebaseEmulator = false,
  });

  /// `APP_CHECK_DEBUG=true` — registre o token de debug no Firebase Console.
  static const debugDefine = bool.fromEnvironment(
    'APP_CHECK_DEBUG',
    defaultValue: false,
  );

  /// `USE_FIREBASE_EMULATOR=true` — usa debug provider fora de release.
  static const emulatorDefine = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const recaptchaEnterpriseDefine = String.fromEnvironment(
    'RECAPTCHA_ENTERPRISE_SITE_KEY',
    defaultValue: '',
  );

  static const recaptchaV3Define = String.fromEnvironment(
    'RECAPTCHA_V3_SITE_KEY',
    defaultValue: '',
  );

  final bool useDebugProvider;
  final String? recaptchaEnterpriseSiteKey;
  final String? recaptchaV3SiteKey;
  final bool useFirebaseEmulator;

  static AppCheckConfig fromEnvironment() {
    final useDebug = !kReleaseMode && (debugDefine || emulatorDefine);
    return AppCheckConfig(
      useDebugProvider: useDebug,
      recaptchaEnterpriseSiteKey: recaptchaEnterpriseDefine.isEmpty
          ? null
          : recaptchaEnterpriseDefine,
      recaptchaV3SiteKey:
          recaptchaV3Define.isEmpty ? null : recaptchaV3Define,
      useFirebaseEmulator: emulatorDefine,
    );
  }

  /// Impede build release com provider de debug (dart-define acidental).
  void assertProductionSafe() {
    if (kReleaseMode && (debugDefine || emulatorDefine)) {
      throw StateError(
        'APP_CHECK_DEBUG / USE_FIREBASE_EMULATOR não podem estar ativos em release.',
      );
    }
  }

  bool get enableDiagnosticLogs => kDebugMode || useDebugProvider;

  AndroidAppCheckProvider get androidProvider {
    if (useDebugProvider) return const AndroidDebugProvider();
    return const AndroidPlayIntegrityProvider();
  }

  AppleAppCheckProvider get appleProvider {
    if (useDebugProvider) return const AppleDebugProvider();
    return const AppleAppAttestWithDeviceCheckFallbackProvider();
  }

  /// Web: Enterprise preferencial; V3 como fallback configurável.
  ReCaptchaEnterpriseProvider? get webEnterpriseProvider {
    final key = recaptchaEnterpriseSiteKey;
    if (key == null || key.isEmpty) return null;
    return ReCaptchaEnterpriseProvider(key);
  }

  ReCaptchaV3Provider? get webV3Provider {
    final key = recaptchaV3SiteKey;
    if (key == null || key.isEmpty) return null;
    return ReCaptchaV3Provider(key);
  }

  /// Provider efetivo para `activate` na web.
  Object? resolveWebProvider() {
    if (!kIsWeb) return null;
    if (useDebugProvider) {
      final v3 = webV3Provider;
      if (v3 != null) return v3;
      final ent = webEnterpriseProvider;
      if (ent != null) return ent;
      throw StateError(
        'Web debug App Check: defina RECAPTCHA_V3_SITE_KEY ou '
        'RECAPTCHA_ENTERPRISE_SITE_KEY e registre o token de debug no Console.',
      );
    }
    final enterprise = webEnterpriseProvider;
    if (enterprise != null) return enterprise;
    final v3 = webV3Provider;
    if (v3 != null) return v3;
    if (kDebugMode) {
      throw StateError(
        'Web App Check: defina RECAPTCHA_ENTERPRISE_SITE_KEY ou '
        'RECAPTCHA_V3_SITE_KEY (ou APP_CHECK_DEBUG=true com token no Console).',
      );
    }
    throw StateError(
      'Web App Check em produção exige RECAPTCHA_ENTERPRISE_SITE_KEY '
      'ou RECAPTCHA_V3_SITE_KEY via --dart-define.',
    );
  }
}
