import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/feature_flags/feature_modules.dart';
import 'package:flutter_application_1/models/feature_flag_model.dart';
import 'package:flutter_application_1/widgets/feature_flags/feature_gate.dart';

void main() {
  group('FeatureFlagModel', () {
    test('enabledDefault — ativo sem manutenção', () {
      final m = FeatureFlagModel.enabledDefault(FeatureModules.flashcards);
      expect(m.enabled, true);
      expect(m.maintenanceMode, false);
      expect(m.isAccessible, true);
    });

    test('fromDoc — interpreta campos', () {
      final m = FeatureFlagModel.fromDoc('questoes', {
        'enabled': false,
        'maintenanceMode': true,
        'maintenanceMessage': 'Volte amanhã',
      });
      expect(m.enabled, false);
      expect(m.maintenanceMode, true);
      expect(m.maintenanceMessage, 'Volte amanhã');
      expect(m.isAccessible, false);
    });
  });

  group('FeatureGate.resolveOnPressed', () {
    testWidgets('módulo ativo chama onEnabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final onPressed = FeatureGate.resolveOnPressed(
                context: context,
                flag: FeatureFlagModel.enabledDefault(FeatureModules.questoes),
                onEnabled: () {
                  tapped = true;
                },
              );
              return ElevatedButton(
                onPressed: onPressed,
                child: const Text('Go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      expect(tapped, isTrue);
    });

    testWidgets('desativado — onPressed null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final onPressed = FeatureGate.resolveOnPressed(
                context: context,
                flag: FeatureFlagModel.fromDoc('x', {'enabled': false}),
                onEnabled: () {},
              );
              return ElevatedButton(
                onPressed: onPressed,
                child: const Text('Go'),
              );
            },
          ),
        ),
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('manutenção abre MaintenancePage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final onPressed = FeatureGate.resolveOnPressed(
                context: context,
                flag: FeatureFlagModel.fromDoc('x', {
                  'enabled': true,
                  'maintenanceMode': true,
                  'maintenanceMessage': 'Manutenção programada',
                }),
                onEnabled: () {},
              );
              return ElevatedButton(
                onPressed: onPressed,
                child: const Text('Go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Em manutenção'), findsOneWidget);
      expect(find.text('Manutenção programada'), findsOneWidget);
    });
  });
}
