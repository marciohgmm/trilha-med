import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/permissions/app_permission.dart';
import 'package:flutter_application_1/core/permissions/permission_checker.dart';
import 'package:flutter_application_1/core/rbac/rbac_catalog.dart';

void main() {
  setUp(() {
    PermissionChecker.bindCatalog(RbacCatalog.fallback());
  });

  group('PermissionChecker', () {
    test('founder tem todas as permissões', () {
      final ctx = PermissionChecker.fromUserDoc(
        userId: 'founder',
        userData: const {},
        isFounder: true,
        isLegacyAdmin: false,
      );
      expect(ctx.has(AppPermission.rbacManage), isTrue);
      expect(ctx.has(AppPermission.notificationBroadcast), isTrue);
      expect(ctx.has(AppPermission.analyticsView), isTrue);
    });

    test('usuário comum não acessa painel admin', () {
      final ctx = PermissionChecker.fromUserDoc(
        userId: 'u1',
        userData: const {},
        isFounder: false,
        isLegacyAdmin: false,
      );
      expect(ctx.canAccessAdminPanel, isFalse);
      expect(ctx.has(AppPermission.subscriptionManage), isFalse);
    });

    test('legacy admin com isAdmin acessa painel', () {
      final ctx = PermissionChecker.fromUserDoc(
        userId: 'admin1',
        userData: const {'isAdmin': true},
        isFounder: false,
        isLegacyAdmin: true,
      );
      expect(ctx.canAccessAdminPanel, isTrue);
    });

    test('rbacRoles finance tem payment.view', () {
      final ctx = PermissionChecker.fromUserDoc(
        userId: 'fin',
        userData: const {
          'rbacRoles': ['finance'],
        },
        isFounder: false,
        isLegacyAdmin: false,
      );
      expect(ctx.has(AppPermission.paymentView), isTrue);
      expect(ctx.has(AppPermission.rbacManage), isFalse);
    });

    test('extraPermissions dinâmicas são aplicadas', () {
      final ctx = PermissionChecker.fromUserDoc(
        userId: 'u2',
        userData: const {
          'extraPermissions': ['analytics.view'],
        },
        isFounder: false,
        isLegacyAdmin: false,
      );
      expect(ctx.has(AppPermission.analyticsView), isTrue);
    });
  });
}
