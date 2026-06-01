import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/platform/master_admin_diagnostics_models.dart';
import '../../application/platform/master_admin_diagnostics_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../application/rbac/rbac_service.dart';
import '../../core/audit/audit_event_type.dart';
import '../../core/permissions/permission_context.dart';
import '../../widgets/admin/admin_gate.dart';
import '../../widgets/admin/rbac_gate.dart';
import '../../widgets/master_admin/master_admin_diagnostics_dialog.dart';
import '../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import 'master_admin_destinations.dart';

/// Shell do Painel Administrativo Mestre — navegação por permissão RBAC.
class MasterAdminShell extends StatefulWidget {
  const MasterAdminShell({super.key});

  @override
  State<MasterAdminShell> createState() => _MasterAdminShellState();
}

class _MasterAdminShellState extends State<MasterAdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _rbac = RbacService.instance;
  final _diagnostics = MasterAdminDiagnosticsService();
  PermissionContext? _ctx;
  MasterAdminDiagnosticReport? _diagnosticReport;
  int _selectedIndex = 0;
  List<MasterAdminDestination> _visible = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _runDiagnostics() async {
    final report = await _diagnostics.run();
    if (mounted) {
      setState(() => _diagnosticReport = report);
    }
  }

  Future<void> _bootstrap() async {
    final ctx = await _rbac.resolveContext();
    final visible = <MasterAdminDestination>[];
    for (final d in MasterAdminDestinations.all) {
      if (ctx.hasKey(d.permissionKey)) visible.add(d);
    }
    if (visible.isEmpty && ctx.canAccessAdminPanel) {
      visible.add(MasterAdminDestinations.all.first);
    }

    await _runDiagnostics();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await PlatformRegistry.instance.audit.log(
          eventType: AuditEventType.adminAction,
          actorUserId: user.uid,
          entityType: 'master_admin',
          entityId: 'shell.open',
          metadata: {'modules': visible.map((e) => e.id).toList()},
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _ctx = ctx;
        _visible = visible;
        if (_selectedIndex >= visible.length) _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      routeName: 'master.shell',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_ctx == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_visible.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Painel Mestre'),
          backgroundColor: MasterAdminDestinations.brandColor,
          foregroundColor: Colors.white,
          actions: [
            if (_diagnosticReport?.shouldShowPanel == true)
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                onPressed: () => _openDiagnosticsDialog(context),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_diagnosticReport?.shouldShowPanel == true)
              MasterAdminDiagnosticsBanner(
                report: _diagnosticReport!,
                onExpand: () => _openDiagnosticsDialog(context),
              ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sua conta não possui permissões para módulos do painel mestre.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final destination = _visible[_selectedIndex];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Painel Mestre — Trilha Med'),
        backgroundColor: MasterAdminDestinations.brandColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_diagnosticReport?.shouldShowPanel == true)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Diagnóstico técnico Firestore',
              onPressed: () => _openDiagnosticsDialog(context),
            ),
          if (!wide)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
        ],
      ),
      body: MasterAdminDiagnosticsScope(
        report: _diagnosticReport,
        onRefresh: _runDiagnostics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_diagnosticReport?.shouldShowPanel == true)
              MasterAdminDiagnosticsBanner(
                report: _diagnosticReport!,
                onExpand: () => _openDiagnosticsDialog(context),
              ),
            Expanded(
              child: Row(
                children: [
                  if (wide) _buildRail() else const SizedBox.shrink(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RbacGate(
                        routeName: destination.routeName,
                        requiredPermissionKey: destination.permissionKey,
                        child: destination.pageBuilder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _visible
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
      drawer: wide ? null : _buildDrawer(),
    );
  }

  Widget _buildRail() {
    return NavigationRail(
      extended: MediaQuery.sizeOf(context).width >= 1100,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
      selectedLabelTextStyle: const TextStyle(
        color: Color(0xFF1E3A8A),
        fontWeight: FontWeight.w600,
      ),
      destinations: _visible
          .map(
            (d) => NavigationRailDestination(
              icon: Icon(d.icon),
              label: Text(d.label),
            ),
          )
          .toList(),
    );
  }

  void _openDiagnosticsDialog(BuildContext context) {
    final report = _diagnosticReport;
    if (report == null) return;
    showMasterAdminDiagnosticsDialog(
      context,
      report: report,
      onRefresh: _runDiagnostics,
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1E3A8A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Painel Mestre',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                SizedBox(height: 4),
                Text(
                  'Plataforma Trilha Med',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ...List.generate(_visible.length, (i) {
            final d = _visible[i];
            return ListTile(
              leading: Icon(d.icon),
              title: Text(d.label),
              selected: _selectedIndex == i,
              onTap: () {
                setState(() => _selectedIndex = i);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}
