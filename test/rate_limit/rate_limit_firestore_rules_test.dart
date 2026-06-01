import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Etapa E — platform_rate_limits inacessível ao cliente', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('match /platform_rate_limits/{docId}'));
    expect(rules, contains('allow read, write: if false'));
  });
}
