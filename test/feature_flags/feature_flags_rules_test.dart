import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore — platform_feature_flags', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('match /platform_feature_flags/{flagId}'));
    expect(rules, contains('allow read: if isSignedIn()'));
    expect(rules, contains('allow create, update: if isAppAdmin()'));
    expect(rules, contains('allow delete: if false'));
  });

  test('auditoria — feature_flag.updated', () {
    final audit = File('lib/core/audit/audit_event_type.dart').readAsStringSync();
    expect(audit, contains("featureFlagUpdated('feature_flag.updated')"));
  });

  test('RBAC — feature_flags.manage', () {
    final perm = File('lib/core/permissions/app_permission.dart')
        .readAsStringSync();
    expect(perm, contains("featureFlagsManage('feature_flags.manage')"));
  });
}
