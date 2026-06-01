import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_check/app_check_config.dart';

/// Inicializa Firebase App Check no arranque (antes de Firestore/Functions sensíveis).
class AppCheckService {
  AppCheckService._();
  static final AppCheckService instance = AppCheckService._();

  bool _initialized = false;
  AppCheckConfig? _config;

  bool get isInitialized => _initialized;

  AppCheckConfig? get config => _config;

  Future<void> initialize() async {
    if (_initialized) return;

    final config = AppCheckConfig.fromEnvironment();
    config.assertProductionSafe();
    _config = config;

    try {
      if (kIsWeb) {
        final webProvider = config.resolveWebProvider();
        if (webProvider is ReCaptchaEnterpriseProvider) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: webProvider,
          );
        } else if (webProvider is ReCaptchaV3Provider) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: webProvider,
          );
        } else {
          throw StateError('Web App Check: provider não resolvido.');
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: config.androidProvider,
          providerApple: config.appleProvider,
        );
      }

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

      if (config.enableDiagnosticLogs) {
        unawaited(_logStartupDiagnostics(config));
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('AppCheckService.initialize: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      if (kReleaseMode) rethrow;
      // Em debug sem Console configurado: não bloqueia o restante do app.
    }
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await FirebaseAppCheck.instance.getToken(forceRefresh);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppCheckService.getToken: $e');
      }
      return null;
    }
  }

  Future<void> _logStartupDiagnostics(AppCheckConfig config) async {
    final mode = config.useDebugProvider ? 'debug' : 'production';
    final platform = defaultTargetPlatform.name;
    debugPrint(
      'App Check: mode=$mode platform=$platform '
      'emulator=${config.useFirebaseEmulator}',
    );
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('App Check: token indisponível (registre debug token no Console).');
        return;
      }
      final preview = token.length > 12 ? '${token.substring(0, 12)}…' : token;
      debugPrint('App Check: token OK ($preview)');
    } catch (e) {
      debugPrint('App Check: falha ao obter token — $e');
    }
  }
}
