import 'package:universal_html/html.dart' as html;

/// Espelha mensagens App Check no DevTools do navegador (Edge/Chrome).
void logAppCheckToBrowserConsole(String message) {
  html.window.console.log(message);
}
