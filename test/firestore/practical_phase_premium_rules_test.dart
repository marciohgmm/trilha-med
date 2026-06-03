import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUp(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  test('hasPremium verifica entitlements estáveis em users', () {
    expect(rules, contains('function hasPremium()'));
    expect(rules, contains("userEntitlementActive(request.auth.uid, 'premium', 'premium')"));
    expect(rules, contains("userEntitlementActive(request.auth.uid, 'premium_lifetime', 'premium_lifetime')"));
    expect(rules, contains('platform_entitlements'));
  });

  test('practical_phase_models usa canReadPracticalPhaseStudentContent', () {
    final block = RegExp(
      r'match /practical_phase_models/\{modelId\}[\s\S]*?match /practical_phase_modules',
    ).firstMatch(rules);
    expect(block, isNotNull);
    expect(block!.group(0), contains('canReadPracticalPhaseStudentContent'));
  });

  test('requiresPremium ausente trata como gratuito', () {
    expect(rules, contains("resource.data.get('requiresPremium', false)"));
  });
}
