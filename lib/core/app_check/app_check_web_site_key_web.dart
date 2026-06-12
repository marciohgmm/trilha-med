import 'package:universal_html/js.dart' as js;

String? _readWindowString(String property) {
  try {
    final value = js.context[property];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Lê `window.TRILHA_MED_RECAPTCHA_V3_SITE_KEY` definido em `web/index.html`.
String? readRecaptchaV3SiteKeyFromHtml() =>
    _readWindowString('TRILHA_MED_RECAPTCHA_V3_SITE_KEY');

/// Lê `window.TRILHA_MED_RECAPTCHA_ENTERPRISE_SITE_KEY` definido em `web/index.html`.
String? readRecaptchaEnterpriseSiteKeyFromHtml() =>
    _readWindowString('TRILHA_MED_RECAPTCHA_ENTERPRISE_SITE_KEY');
