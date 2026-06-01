import '../../domain/platform/models/admin_dashboard_snapshot.dart';
import 'platform_registry.dart';

/// Carrega métricas do painel mestre via [PlatformRegistry].
class MasterAdminDashboardService {
  MasterAdminDashboardService({PlatformRegistry? registry})
      : _registry = registry ?? PlatformRegistry.instance;

  final PlatformRegistry _registry;

  Future<AdminDashboardSnapshot> loadSnapshot() {
    return _registry.repositories.dashboard.loadSnapshot();
  }
}
