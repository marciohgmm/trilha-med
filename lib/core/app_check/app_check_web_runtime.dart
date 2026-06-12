import 'app_check_config.dart';
import 'app_check_web_site_key.dart';

/// Chaves reCAPTCHA efetivas na web (dart-define + `web/index.html`).
class AppCheckWebRuntimeKeys {
  const AppCheckWebRuntimeKeys({
    this.recaptchaV3SiteKey,
    this.recaptchaEnterpriseSiteKey,
  });

  final String? recaptchaV3SiteKey;
  final String? recaptchaEnterpriseSiteKey;

  bool get hasAny =>
      _nonEmpty(recaptchaV3SiteKey) != null ||
      _nonEmpty(recaptchaEnterpriseSiteKey) != null;

  String? get primaryV3 => _nonEmpty(recaptchaV3SiteKey);

  String? get primaryEnterprise => _nonEmpty(recaptchaEnterpriseSiteKey);

  static AppCheckWebRuntimeKeys resolve(AppCheckConfig config) {
    return AppCheckWebRuntimeKeys(
      recaptchaV3SiteKey: _firstNonEmpty([
        config.recaptchaV3SiteKey,
        readRecaptchaV3SiteKeyFromHtml(),
      ]),
      recaptchaEnterpriseSiteKey: _firstNonEmpty([
        config.recaptchaEnterpriseSiteKey,
        readRecaptchaEnterpriseSiteKeyFromHtml(),
      ]),
    );
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      final v = _nonEmpty(c);
      if (v != null) return v;
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  /// Comando sugerido quando falta site key na web.
  static String edgeDebugRunHint() {
    return 'flutter run -d edge --web-port=1234 '
        '--dart-define=APP_CHECK_DEBUG=true '
        '--dart-define=RECAPTCHA_V3_SITE_KEY=SUA_SITE_KEY_AQUI';
  }

  static String missingKeyMessage(AppCheckConfig config) {
    final fromDefine = config.recaptchaV3SiteKey != null ||
        config.recaptchaEnterpriseSiteKey != null;
    final htmlHint =
        'ou defina window.TRILHA_MED_RECAPTCHA_V3_SITE_KEY em web/index.html';
    if (fromDefine) {
      return 'Site key reCAPTCHA inválida ou vazia. Confira RECAPTCHA_V3_SITE_KEY '
          'no Firebase Console → App Check → Web.';
    }
    return 'Web App Check exige RECAPTCHA_V3_SITE_KEY (ou RECAPTCHA_ENTERPRISE_SITE_KEY). '
        'Passe --dart-define=RECAPTCHA_V3_SITE_KEY=... no flutter run $htmlHint. '
        'Exemplo: ${edgeDebugRunHint()}';
  }
}
