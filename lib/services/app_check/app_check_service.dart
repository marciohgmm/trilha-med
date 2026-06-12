import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_check/app_check_config.dart';
import '../../core/app_check/app_check_token_result.dart';
import '../../core/app_check/app_check_web_console.dart';
import '../../core/app_check/app_check_web_runtime.dart';

/// Falha ao preparar App Check antes de callables protegidas.
class AppCheckNotReadyException implements Exception {
  AppCheckNotReadyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Inicializa Firebase App Check no arranque (antes de Firestore/Functions sensíveis).
///
/// **Android/iOS:** em debug usa AndroidDebugProvider; getToken no boot é omitido
/// para evitar rate limit. Release exige token válido com Play Integrity.
/// **Web:** sempre usa reCAPTCHA v3/Enterprise + debug token no Console se `APP_CHECK_DEBUG=true`.
class AppCheckService {
  AppCheckService._();

  static final AppCheckService instance = AppCheckService._();

  static const _debugMinInterval = Duration(seconds: 45);
  static const _rateLimitCooldown = Duration(minutes: 2);
  static const _debugTokenCacheTtl = Duration(minutes: 10);
  static const _releaseTokenCacheTtl = Duration(minutes: 30);

  bool _initialized = false;
  bool _usingDebugProvider = false;
  AppCheckConfig? _config;
  AppCheckWebRuntimeKeys? _webRuntime;
  String? _lastError;
  String? _activeProviderLabel;
  Future<bool>? _initFuture;

  String? _cachedToken;
  DateTime? _cachedTokenAt;
  AppCheckGetTokenResult? _lastTokenResult;
  DateTime? _lastTokenAttemptAt;
  DateTime? _rateLimitedUntil;
  Future<AppCheckGetTokenResult>? _inFlightTokenRequest;

  bool get isInitialized => _initialized;
  AppCheckConfig? get config => _config;
  bool get usingDebugProvider => _usingDebugProvider;
  String? get lastError => _lastError;
  String? get activeProviderLabel => _activeProviderLabel;
  AppCheckTokenFailureKind? get lastTokenFailureKind => _lastTokenResult?.failureKind;

  Future<void> ensureReady() async {
    final ok = await initialize();
    if (!ok) {
      throw AppCheckNotReadyException(
        _lastError ??
            'App Check não está pronto. Veja os logs [AppCheck] no terminal/console.',
      );
    }
  }

  Future<bool> initialize() {
    if (_initialized) return SynchronousFuture(true);
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<bool> _doInitialize() async {
    final envConfig = AppCheckConfig.fromEnvironment();
    envConfig.assertProductionSafe();
    _config = envConfig;

    if (kIsWeb) {
      _webRuntime = AppCheckWebRuntimeKeys.resolve(envConfig);
      _logBootConfig(envConfig, webRuntime: _webRuntime);
      if (!_webRuntime!.hasAny) {
        _lastError = AppCheckWebRuntimeKeys.missingKeyMessage(envConfig);
        _logWebSetupHelp(envConfig);
        return false;
      }
    } else {
      _logBootConfig(envConfig);
    }

    if (!envConfig.supportsNativeActivation && !kIsWeb) {
      _lastError =
          'App Check não suporta ${envConfig.platformLabel} neste build. '
          'Teste checkout em Android, iOS, macOS ou Web.';
      debugPrint('[AppCheck] ERRO: $_lastError');
      return false;
    }

    final primaryOk = await _tryActivate(
      envConfig,
      useDebug: envConfig.useDebugProvider,
      webRuntime: _webRuntime,
    );
    if (primaryOk) {
      return _finalizeSuccess(envConfig, envConfig.useDebugProvider);
    }

    if (kIsWeb) {
      debugPrint('[AppCheck] FALHA web: $_lastError');
      return false;
    }

    if (kDebugMode && !envConfig.useDebugProvider) {
      debugPrint(
        '[AppCheck] Provider de produção falhou em debug — '
        'tentando fallback AndroidDebugProvider / AppleDebugProvider. '
        'Dica: use --dart-define=APP_CHECK_DEBUG=true',
      );
      final debugConfig = envConfig.withDebugProvider();
      final fallbackOk = await _tryActivate(
        debugConfig,
        useDebug: true,
        webRuntime: _webRuntime,
      );
      if (fallbackOk) {
        return _finalizeSuccess(debugConfig, true);
      }
    }

    debugPrint('[AppCheck] FALHA definitiva: $_lastError');
    return false;
  }

  void _logBootConfig(
    AppCheckConfig envConfig, {
    AppCheckWebRuntimeKeys? webRuntime,
  }) {
    final webKeys = kIsWeb && webRuntime != null
        ? ' keys=${envConfig.maskedWebKeySummary(webRuntime)}'
        : '';
    debugPrint(
      '[AppCheck] boot platform=${envConfig.platformLabel} '
      'debugDefine=${envConfig.debugDefineActive} '
      'APP_CHECK_DEBUG=${AppCheckConfig.debugDefine} '
      'emulatorDefine=${envConfig.emulatorDefineActive} '
      'useDebugProvider=${envConfig.useDebugProvider}$webKeys',
    );
    logAppCheckToBrowserConsole(
      '[AppCheck] boot platform=${envConfig.platformLabel} '
      'APP_CHECK_DEBUG=${AppCheckConfig.debugDefine}$webKeys',
    );
  }

  void _logWebSetupHelp(AppCheckConfig envConfig) {
    final msg = AppCheckWebRuntimeKeys.missingKeyMessage(envConfig);
    debugPrint('[AppCheck] ERRO web: $msg');
    debugPrint('[AppCheck] Comando sugerido: ${AppCheckWebRuntimeKeys.edgeDebugRunHint()}');
    logAppCheckToBrowserConsole('[AppCheck] ERRO: $msg');
    logAppCheckToBrowserConsole(
      '[AppCheck] Comando: ${AppCheckWebRuntimeKeys.edgeDebugRunHint()}',
    );
  }

  Future<bool> _tryActivate(
    AppCheckConfig cfg, {
    required bool useDebug,
    AppCheckWebRuntimeKeys? webRuntime,
  }) async {
    final runtime = webRuntime ??
        (kIsWeb ? AppCheckWebRuntimeKeys.resolve(cfg) : const AppCheckWebRuntimeKeys());
    final label = cfg.providerLabel(useDebug: useDebug, webRuntime: runtime);
    try {
      if (kIsWeb) {
        final webProvider = cfg.resolveWebProvider(
          useDebug: useDebug,
          runtime: runtime,
        );
        if (webProvider is ReCaptchaEnterpriseProvider) {
          await FirebaseAppCheck.instance.activate(providerWeb: webProvider);
        } else if (webProvider is ReCaptchaV3Provider) {
          await FirebaseAppCheck.instance.activate(providerWeb: webProvider);
        } else {
          throw StateError('Web App Check: provider não resolvido.');
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: useDebug
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: useDebug
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      }

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _activeProviderLabel = label;
      debugPrint('[AppCheck] activate OK — provider=$label');
      logAppCheckToBrowserConsole('[AppCheck] activate OK — provider=$label');
      return true;
    } catch (e, st) {
      _lastError = '$label: $e';
      debugPrint('[AppCheck] activate FALHOU — provider=$label erro=$e');
      logAppCheckToBrowserConsole('[AppCheck] activate FALHOU: $e');
      if (kDebugMode) debugPrint('$st');
      return false;
    }
  }

  Future<bool> _finalizeSuccess(AppCheckConfig cfg, bool useDebug) async {
    _usingDebugProvider = useDebug;
    _config = cfg;

    // Debug nativo: não chamar getToken no boot — evita rate limit antes do checkout.
    if (useDebug && !kIsWeb && kDebugMode && !kReleaseMode) {
      _initialized = true;
      _lastError =
          'activate OK; getToken adiado em debug (evita rate limit no boot)';
      debugPrint(
        '[AppCheck] inicializado em debug (provider=${_activeProviderLabel ?? "?"}); '
        'getToken só no checkout.',
      );
      logAppCheckToBrowserConsole(
        '[AppCheck] debug: activate OK; getToken adiado',
      );
      return true;
    }

    final result = await getTokenResult(forceRefresh: false);
    if (result.ok) {
      _initialized = true;
      _lastError = null;
      final preview = result.token!.length > 16
          ? '${result.token!.substring(0, 16)}…'
          : result.token!;
      debugPrint(
        '[AppCheck] inicializado com sucesso provider=${_activeProviderLabel ?? "?"} '
        'debug=$useDebug tokenPreview=$preview',
      );
      logAppCheckToBrowserConsole(
        '[AppCheck] OK provider=${_activeProviderLabel ?? "?"} debug=$useDebug',
      );
      if (useDebug || cfg.enableDiagnosticLogs) {
        _logAppCheckJwtPreview(result.token!, useDebug: useDebug);
      }
      return true;
    }

    if (kReleaseMode) {
      _lastError = result.technicalDetail ?? result.userMessage;
      debugPrint('[AppCheck] FALHA pós-activate: $_lastError');
      logAppCheckToBrowserConsole('[AppCheck] FALHA pós-activate: $_lastError');
      return false;
    }

    _initialized = true;
    _lastError = result.userMessage;
    debugPrint('[AppCheck] inicializado com aviso: $_lastError');
    return true;
  }

  /// Obtém token com cache, deduplicação e cooldown (evita "Too many attempts").
  Future<AppCheckGetTokenResult> getTokenResult({bool forceRefresh = false}) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        return _rememberTokenResult(
          AppCheckGetTokenResult.failure(
            kind: AppCheckTokenFailureKind.notInitialized,
            technicalDetail: _lastError,
          ),
        );
      }
    }

    final effectiveForceRefresh = forceRefresh && (kReleaseMode || kIsWeb);

    if (!effectiveForceRefresh && _hasFreshCachedToken()) {
      return AppCheckGetTokenResult.success(_cachedToken!);
    }

    final rateLimitWait = _secondsUntilRateLimitEnds();
    if (rateLimitWait > 0) {
      if (!effectiveForceRefresh &&
          _lastTokenResult != null &&
          !_lastTokenResult!.ok) {
        return _lastTokenResult!;
      }
      return _rememberTokenResult(
        AppCheckGetTokenResult.failure(
          kind: AppCheckTokenFailureKind.rateLimited,
          technicalDetail: 'rate limit ativo até $_rateLimitedUntil',
          retryAfterSeconds: rateLimitWait,
        ),
      );
    }

    if (_usingDebugProvider && !kIsWeb && !effectiveForceRefresh) {
      final cooldown = _secondsUntilDebugCooldownEnds();
      if (cooldown > 0) {
        if (_lastTokenResult?.ok == true && _hasFreshCachedToken()) {
          return AppCheckGetTokenResult.success(_cachedToken!);
        }
        if (_lastTokenResult != null && !_lastTokenResult!.ok) {
          return AppCheckGetTokenResult.failure(
            kind: _lastTokenResult!.failureKind ?? AppCheckTokenFailureKind.unknown,
            technicalDetail: _lastTokenResult!.technicalDetail,
            retryAfterSeconds: cooldown,
          );
        }
      }
    }

    if (_inFlightTokenRequest != null) {
      return _inFlightTokenRequest!;
    }

    _inFlightTokenRequest = _fetchTokenFromFirebase(
      forceRefresh: effectiveForceRefresh,
    ).whenComplete(() => _inFlightTokenRequest = null);
    return _inFlightTokenRequest!;
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    final result = await getTokenResult(forceRefresh: forceRefresh);
    return result.token;
  }

  Future<AppCheckGetTokenResult> _fetchTokenFromFirebase({
    required bool forceRefresh,
  }) async {
    _lastTokenAttemptAt = DateTime.now();
    final useDebug = _usingDebugProvider;
    final maxAttempts = kReleaseMode && !useDebug ? 2 : 1;

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        debugPrint('[AppCheck] getToken retry release $attempt/$maxAttempts');
      }
      try {
        final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
        if (token == null || token.isEmpty) {
          return _rememberTokenResult(
            AppCheckGetTokenResult.failure(
              kind: AppCheckTokenFailureKind.empty,
              technicalDetail: 'getToken retornou vazio',
            ),
          );
        }
        _cacheToken(token);
        _rateLimitedUntil = null;
        _lastError = null;
        debugPrint('[AppCheck] getToken OK');
        return _rememberTokenResult(AppCheckGetTokenResult.success(token));
      } catch (e, st) {
        lastError = e;
        final kind = _classifyTokenError(e, useDebug: useDebug);
        debugPrint('[AppCheck] getToken falhou ($kind): $e');

        if (kind == AppCheckTokenFailureKind.rateLimited) {
          _rateLimitedUntil = DateTime.now().add(_rateLimitCooldown);
          final wait = _secondsUntilRateLimitEnds();
          return _rememberTokenResult(
            AppCheckGetTokenResult.failure(
              kind: kind,
              technicalDetail: e.toString(),
              retryAfterSeconds: wait,
            ),
          );
        }

        if (kind == AppCheckTokenFailureKind.network &&
            attempt < maxAttempts &&
            kReleaseMode) {
          continue;
        }

        if (kDebugMode) debugPrint('$st');
        _logClassifiedFailure(kind, e);
        return _rememberTokenResult(
          AppCheckGetTokenResult.failure(
            kind: kind,
            technicalDetail: e.toString(),
          ),
        );
      }
    }

    return _rememberTokenResult(
      AppCheckGetTokenResult.failure(
        kind: AppCheckTokenFailureKind.unknown,
        technicalDetail: lastError?.toString(),
      ),
    );
  }

  AppCheckGetTokenResult _rememberTokenResult(AppCheckGetTokenResult result) {
    _lastTokenResult = result;
    if (!result.ok) {
      _lastError = result.technicalDetail ?? result.userMessage;
    }
    return result;
  }

  void _cacheToken(String token) {
    _cachedToken = token;
    _cachedTokenAt = DateTime.now();
  }

  bool _hasFreshCachedToken() {
    if (_cachedToken == null || _cachedTokenAt == null) return false;
    final ttl = _usingDebugProvider && !kReleaseMode
        ? _debugTokenCacheTtl
        : _releaseTokenCacheTtl;
    return DateTime.now().difference(_cachedTokenAt!) < ttl;
  }

  int _secondsUntilRateLimitEnds() {
    if (_rateLimitedUntil == null) return 0;
    final remaining = _rateLimitedUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  int _secondsUntilDebugCooldownEnds() {
    if (_lastTokenAttemptAt == null) return 0;
    final elapsed = DateTime.now().difference(_lastTokenAttemptAt!);
    final remaining = _debugMinInterval - elapsed;
    if (remaining.isNegative) return 0;
    return remaining.inSeconds.clamp(1, _debugMinInterval.inSeconds);
  }

  AppCheckTokenFailureKind _classifyTokenError(
    Object error, {
    required bool useDebug,
  }) {
    final message = error.toString().toLowerCase();
    if (message.contains('too many attempts')) {
      return AppCheckTokenFailureKind.rateLimited;
    }
    if (_looksLikeNetworkError(message)) {
      return AppCheckTokenFailureKind.network;
    }
    if (message.contains('app attestation failed') ||
        message.contains('403') ||
        message.contains('attestation')) {
      return useDebug
          ? AppCheckTokenFailureKind.missingDebugSecret
          : AppCheckTokenFailureKind.unknown;
    }
    return AppCheckTokenFailureKind.unknown;
  }

  bool _looksLikeNetworkError(String message) {
    return message.contains('unable to resolve host') ||
        message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network is unreachable') ||
        message.contains('connection timed out') ||
        message.contains('connection refused') ||
        message.contains('no address associated with hostname') ||
        message.contains('eai_nodata') ||
        message.contains('getaddrinfo') ||
        message.contains('nodata');
  }

  void _logClassifiedFailure(AppCheckTokenFailureKind kind, Object error) {
    debugPrint('[AppCheck] falha categorizada=$kind detalhe=$error');
    if (kind == AppCheckTokenFailureKind.network) {
      debugPrint(
        '[AppCheck] REDE/DNS: confira Wi‑Fi/dados móveis, DNS privado (Android), VPN '
        'e teste: adb shell ping -c 1 firebase.googleapis.com',
      );
    } else if (kind == AppCheckTokenFailureKind.rateLimited) {
      debugPrint(
        '[AppCheck] RATE LIMIT: aguarde o cooldown antes de novo getToken/checkout',
      );
    } else if (kind == AppCheckTokenFailureKind.missingDebugSecret) {
      debugPrint(
        '[AppCheck] DEBUG SECRET: 403 em debug costuma ser secret não cadastrado '
        '(ou rede instável mascarando como attestation failed)',
      );
      if (kIsWeb) {
        _logWebDebugSecretHint();
      } else {
        _logNativeDebugSecretHint();
      }
    } else if (kind == AppCheckTokenFailureKind.empty) {
      debugPrint('[AppCheck] TOKEN VAZIO: activate OK mas exchange não retornou JWT');
    }
  }

  void _logWebDebugSecretHint() {
    logAppCheckToBrowserConsole('');
    logAppCheckToBrowserConsole('══════════════════════════════════════════════════════════');
    logAppCheckToBrowserConsole('[AppCheck] WEB — cadastro do DEBUG TOKEN');
    logAppCheckToBrowserConsole('1. Firebase Console → App Check → seu app Web');
    logAppCheckToBrowserConsole('2. ⋮ → Manage debug tokens → Add debug token');
    logAppCheckToBrowserConsole('3. Cole o token JWT impresso abaixo (somente Web)');
    logAppCheckToBrowserConsole('4. NÃO use token de debug do Android no app Web');
    logAppCheckToBrowserConsole('5. flutter run -d chrome --dart-define=APP_CHECK_DEBUG=true \\');
    logAppCheckToBrowserConsole('     --dart-define=RECAPTCHA_V3_SITE_KEY=SUA_SITE_KEY');
    logAppCheckToBrowserConsole('══════════════════════════════════════════════════════════');
    logAppCheckToBrowserConsole('');
  }

  void _logNativeDebugSecretHint() {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════════');
    debugPrint('[AppCheck] CADASTRO DO DEBUG SECRET (Android/iOS)');
    debugPrint(
      'Procure no logcat/terminal a linha com "DebugAppCheckProvider" '
      'ou "Enter this debug secret".',
    );
    debugPrint(
      'Copie o UUID (ex.: 123a4567-b89c-12d3-e456-789012345678) — '
      'NÃO use o JWT abaixo.',
    );
    debugPrint(
      'Firebase Console → App Check → seu app → ⋮ → Manage debug tokens',
    );
    debugPrint('Reinicie o app após cadastrar o secret.');
    debugPrint('══════════════════════════════════════════════════════════');
    debugPrint('');
  }

  void _logAppCheckJwtPreview(String token, {required bool useDebug}) {
    if (kIsWeb && useDebug) {
      _logWebDebugSecretHint();
    }

    final header = kIsWeb && useDebug
        ? '[AppCheck] WEB — DEBUG TOKEN (cadastre no Firebase Console → App Check → Web → debug tokens)'
        : useDebug
            ? '[AppCheck] JWT App Check (preview — NÃO cadastre no Console; '
                'use o UUID do DebugAppCheckProvider no logcat)'
            : '[AppCheck] App Check token (produção)';

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════════');
    debugPrint(header);
    debugPrint(token);
    debugPrint('══════════════════════════════════════════════════════════');
    debugPrint('');

    logAppCheckToBrowserConsole('');
    logAppCheckToBrowserConsole('══════════════════════════════════════════');
    logAppCheckToBrowserConsole(header);
    logAppCheckToBrowserConsole(token);
    logAppCheckToBrowserConsole('══════════════════════════════════════════');
    logAppCheckToBrowserConsole('');
  }
}
