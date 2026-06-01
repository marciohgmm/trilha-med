import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/permissions/app_permission.dart';
import 'package:flutter_application_1/screens/master_admin/master_admin_destinations.dart';

void main() {
  group('MasterAdminDestinations', () {
    test('ids de destinos são únicos', () {
      final ids = MasterAdminDestinations.all.map((d) => d.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('routeNames são únicos', () {
      final routes =
          MasterAdminDestinations.all.map((d) => d.routeName).toList();
      expect(routes.length, routes.toSet().length);
    });

    test('módulos críticos existem com permissão correta', () {
      final byId = {
        for (final d in MasterAdminDestinations.all) d.id: d,
      };

      expect(byId['dashboard']!.permissionKey, AppPermission.dashboardView.key);
      expect(byId['analytics']!.permissionKey, AppPermission.analyticsView.key);
      expect(
        byId['subscriptions']!.permissionKey,
        AppPermission.subscriptionManage.key,
      );
      expect(byId['payments']!.permissionKey, AppPermission.paymentView.key);
      expect(byId['push']!.permissionKey, AppPermission.notificationBroadcast.key);
      expect(byId['campaigns']!.permissionKey, AppPermission.campaignManage.key);
    });

    test('cada destino constrói página sem lançar', () {
      for (final d in MasterAdminDestinations.all) {
        expect(() => d.pageBuilder(), returnsNormally);
      }
    });
  });
}
