import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter/foundation.dart';



import 'app_check_web_runtime.dart';



/// Configuração de App Check via `--dart-define` (sem ativar debug em release).

///

/// **Android/iOS/macOS:** em `kDebugMode` (ex.: `flutter run`), usa debug provider

/// automaticamente; em `kReleaseMode`, Play Integrity / App Attest.

///

/// **Web:** sempre exige site key reCAPTCHA (v3 ou Enterprise), inclusive em debug.

/// `APP_CHECK_DEBUG=true` habilita o fluxo de **debug token** no Console (web não

/// usa debug provider nativo automaticamente).

///

/// **Produção:** enforcement no Firebase Console — ver

/// [docs/APP_CHECK_PRODUCTION_ENFORCEMENT.md](../../docs/APP_CHECK_PRODUCTION_ENFORCEMENT.md).

class AppCheckConfig {

  const AppCheckConfig({

    required this.useDebugProvider,

    this.recaptchaEnterpriseSiteKey,

    this.recaptchaV3SiteKey,

    this.useFirebaseEmulator = false,

    this.debugDefineActive = false,

    this.emulatorDefineActive = false,

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

  final bool debugDefineActive;

  final bool emulatorDefineActive;



  static AppCheckConfig fromEnvironment() {

    final debugDefineActive = debugDefine;

    final emulatorDefineActive = emulatorDefine;

    final useDebug = !kReleaseMode &&
        (debugDefineActive ||
            emulatorDefineActive ||
            (!kIsWeb && kDebugMode));

    return AppCheckConfig(

      useDebugProvider: useDebug,

      recaptchaEnterpriseSiteKey: recaptchaEnterpriseDefine.isEmpty

          ? null

          : recaptchaEnterpriseDefine,

      recaptchaV3SiteKey:

          recaptchaV3Define.isEmpty ? null : recaptchaV3Define,

      useFirebaseEmulator: emulatorDefineActive,

      debugDefineActive: debugDefineActive,

      emulatorDefineActive: emulatorDefineActive,

    );

  }



  /// Impede build release com provider de debug (dart-define acidental).

  void assertProductionSafe() {

    if (kReleaseMode && (debugDefineActive || emulatorDefineActive)) {

      throw StateError(

        'APP_CHECK_DEBUG / USE_FIREBASE_EMULATOR não podem estar ativos em release.',

      );

    }

  }



  bool get enableDiagnosticLogs => kDebugMode || useDebugProvider;



  bool get supportsNativeActivation {

    if (kIsWeb) return true;

    switch (defaultTargetPlatform) {

      case TargetPlatform.android:

      case TargetPlatform.iOS:

      case TargetPlatform.macOS:

        return true;

      default:

        return false;

    }

  }



  String get platformLabel {

    if (kIsWeb) return 'web';

    return defaultTargetPlatform.name;

  }



  String providerLabel({

    required bool useDebug,

    AppCheckWebRuntimeKeys? webRuntime,

  }) {

    if (kIsWeb) {

      final runtime = webRuntime ?? AppCheckWebRuntimeKeys.resolve(this);

      if (runtime.primaryEnterprise != null) {

        return useDebug ? 'ReCaptcha Enterprise (debug)' : 'ReCaptcha Enterprise';

      }

      if (runtime.primaryV3 != null) {

        return useDebug ? 'ReCaptcha v3 (debug)' : 'ReCaptcha v3';

      }

      return 'ReCaptcha (site key ausente)';

    }

    switch (defaultTargetPlatform) {

      case TargetPlatform.android:

        return useDebug ? 'AndroidDebugProvider' : 'AndroidPlayIntegrityProvider';

      case TargetPlatform.iOS:

        return useDebug ? 'AppleDebugProvider' : 'AppleAppAttest+DeviceCheck';

      case TargetPlatform.macOS:

        return useDebug ? 'AppleDebugProvider' : 'AppleAppAttest+DeviceCheck';

      default:

        return useDebug ? 'debug (indisponível nesta plataforma)' : 'produção';

    }

  }



  AndroidAppCheckProvider get androidProvider {

    if (useDebugProvider) return const AndroidDebugProvider();

    return const AndroidPlayIntegrityProvider();

  }



  AppleAppCheckProvider get appleProvider {

    if (useDebugProvider) return const AppleDebugProvider();

    return const AppleAppAttestWithDeviceCheckFallbackProvider();

  }



  ReCaptchaEnterpriseProvider? webEnterpriseProvider(AppCheckWebRuntimeKeys runtime) {

    final key = runtime.primaryEnterprise;

    if (key == null) return null;

    return ReCaptchaEnterpriseProvider(key);

  }



  ReCaptchaV3Provider? webV3Provider(AppCheckWebRuntimeKeys runtime) {

    final key = runtime.primaryV3;

    if (key == null) return null;

    return ReCaptchaV3Provider(key);

  }



  /// Provider efetivo para `activate` na web (v3 preferencial; Enterprise como fallback).

  Object resolveWebProvider({

    required bool useDebug,

    required AppCheckWebRuntimeKeys runtime,

  }) {

    if (!kIsWeb) {

      throw StateError('resolveWebProvider só na web');

    }



    if (!runtime.hasAny) {

      throw StateError(AppCheckWebRuntimeKeys.missingKeyMessage(this));

    }



    final v3 = webV3Provider(runtime);

    if (v3 != null) return v3;



    final enterprise = webEnterpriseProvider(runtime);

    if (enterprise != null) return enterprise;



    throw StateError(AppCheckWebRuntimeKeys.missingKeyMessage(this));

  }



  AppCheckConfig withDebugProvider() {

    return AppCheckConfig(

      useDebugProvider: true,

      recaptchaEnterpriseSiteKey: recaptchaEnterpriseSiteKey,

      recaptchaV3SiteKey: recaptchaV3SiteKey,

      useFirebaseEmulator: useFirebaseEmulator,

      debugDefineActive: debugDefineActive,

      emulatorDefineActive: emulatorDefineActive,

    );

  }



  String maskedWebKeySummary(AppCheckWebRuntimeKeys runtime) {

    String mask(String? key) {

      if (key == null || key.length < 8) return key == null ? 'ausente' : '***';

      return '${key.substring(0, 4)}…${key.substring(key.length - 4)}';

    }



    return 'v3=${mask(runtime.primaryV3)} enterprise=${mask(runtime.primaryEnterprise)}';

  }

}


