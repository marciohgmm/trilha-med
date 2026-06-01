import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/permissions/app_permission.dart';
import 'package:flutter_application_1/core/permissions/app_role.dart';

void main() {
  group('RolePermissionMatrix', () {
    test('masterAdmin inclui notification.broadcast e analytics.view', () {
      final perms = RolePermissionMatrix.defaults[AppRole.masterAdmin]!;
      expect(perms.contains(AppPermission.notificationBroadcast), isTrue);
      expect(perms.contains(AppPermission.analyticsView), isTrue);
    });

    test('user padrão só content.read', () {
      final perms = RolePermissionMatrix.defaults[AppRole.user]!;
      expect(perms.length, 1);
      expect(perms.contains(AppPermission.contentRead), isTrue);
    });

    test('allKeys cobre todos os enums', () {
      expect(
        RolePermissionMatrix.allKeys.length,
        AppPermission.values.length,
      );
    });
  });
}
