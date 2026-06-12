import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Expectativas de enforcement (espelha functions/test/appCheckEnforcement.test.mjs).
void main() {
  final projectRoot = Directory.current.path.contains('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  final functionsSrc = Directory('$projectRoot/functions/src');

  void expectFileContains(String relativePath, String needle) {
    final file = File('${functionsSrc.path}/$relativePath');
    expect(file.existsSync(), isTrue, reason: relativePath);
    expect(file.readAsStringSync(), contains(needle));
  }

  group('Cloud Functions — enforceAppCheck', () {
    const protectedExports = [
      ('createCheckout.ts', 'createMercadoPagoCheckout'),
      (
        'subscription/paymentReconciliation.ts',
        'reconcileMyMercadoPagoPayments',
      ),
      ('accountDeletion.ts', 'deleteMyAccount'),
      ('push/callables.ts', 'registerFcmToken'),
      ('push/callables.ts', 'createPushCampaign'),
      ('push/callables.ts', 'notifyLiveEventBroadcast'),
      ('push/callables.ts', 'notifyLiveEventUser'),
      ('push/callables.ts', 'scheduleLiveEventReminders'),
    ];

    for (final entry in protectedExports) {
      test('${entry.$2} usa appCheckCallableOptions / enforceAppCheck', () {
        final content = File('${functionsSrc.path}/${entry.$1}')
            .readAsStringSync();
        expect(content, contains('appCheckCallableOptions'));
        expect(content, contains(entry.$2));
      });
    }

    test('mercadopagoWebhook não usa enforceAppCheck', () {
      final content =
          File('${functionsSrc.path}/webhook.ts').readAsStringSync();
      expect(content, contains('mercadopagoWebhook'));
      expect(content, isNot(contains('enforceAppCheck: true')));
    });

    test('callableOptions — invoker public para protocolo callable', () {
      expectFileContains('callableOptions.ts', 'invoker: "public"');
    });

    test('deleteMyAccount protegido', () {
      expectFileContains('accountDeletion.ts', 'deleteMyAccount');
      expectFileContains('accountDeletion.ts', 'appCheckCallableOptions');
    });
  });
}
