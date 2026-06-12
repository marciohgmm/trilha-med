import 'package:flutter/foundation.dart';

/// Resultado de [AppCheckService.getTokenResult] com falhas classificadas.
enum AppCheckTokenFailureKind {
  notInitialized,
  missingDebugSecret,
  network,
  rateLimited,
  empty,
  unknown,
}

class AppCheckGetTokenResult {
  const AppCheckGetTokenResult._({
    this.token,
    this.failureKind,
    this.technicalDetail,
    this.retryAfterSeconds,
  });

  final String? token;
  final AppCheckTokenFailureKind? failureKind;
  final String? technicalDetail;
  final int? retryAfterSeconds;

  bool get ok => token != null && token!.isNotEmpty;

  factory AppCheckGetTokenResult.success(String token) {
    return AppCheckGetTokenResult._(token: token);
  }

  factory AppCheckGetTokenResult.failure({
    required AppCheckTokenFailureKind kind,
    String? technicalDetail,
    int? retryAfterSeconds,
  }) {
    return AppCheckGetTokenResult._(
      failureKind: kind,
      technicalDetail: technicalDetail,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  /// Mensagem curta para UI / checkout (pt-BR).
  String get userMessage {
    if (ok) return '';
    final wait = retryAfterSeconds;
    final waitHint =
        wait != null && wait > 0 ? ' Aguarde cerca de ${wait}s e tente de novo.' : '';

    switch (failureKind) {
      case AppCheckTokenFailureKind.notInitialized:
        return kIsWeb
            ? 'App Check não foi inicializado no site. Recarregue a página e confira '
                'RECAPTCHA_V3_SITE_KEY + APP_CHECK_DEBUG no flutter run.'
            : 'App Check não foi inicializado. Reinicie o app.';
      case AppCheckTokenFailureKind.missingDebugSecret:
        if (kIsWeb) {
          return 'App Check Web não validado. Abra o console do navegador (F12), '
              'copie o token [AppCheck] WEB — DEBUG TOKEN e cadastre em '
              'Firebase Console → App Check → app Web → Manage debug tokens. '
              'Use flutter run com --dart-define=APP_CHECK_DEBUG=true. '
              'Token Android não funciona na Web.';
        }
        return 'App Check debug não validado. Cadastre o debug secret (UUID no logcat '
            '"DebugAppCheckProvider") no Firebase Console → App Check → Manage debug tokens '
            'e reinicie o app. Se o logcat mostrar EAI_NODATA/getaddrinfo, corrija internet/DNS primeiro.';
      case AppCheckTokenFailureKind.network:
        return 'Sem conexão estável para validar App Check. '
            'Verifique internet/DNS e tente novamente.$waitHint';
      case AppCheckTokenFailureKind.rateLimited:
        return 'App Check bloqueou tentativas em excesso (rate limit). '
            'Evite tocar repetidamente no botão de compra.$waitHint';
      case AppCheckTokenFailureKind.empty:
        return 'Token App Check vazio. Reinicie o app e tente novamente.$waitHint';
      case AppCheckTokenFailureKind.unknown:
      case null:
        return 'Não foi possível obter token App Check. '
            'Reinicie o app e tente novamente.$waitHint';
    }
  }
}
