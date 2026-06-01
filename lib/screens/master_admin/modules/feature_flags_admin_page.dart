import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../application/rbac/rbac_service.dart';
import '../../../core/audit/audit_event_type.dart';
import '../../../core/feature_flags/feature_modules.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../models/feature_flag_model.dart';
import '../../../services/feature_flags/feature_flag_service.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class FeatureFlagsAdminPage extends StatefulWidget {
  const FeatureFlagsAdminPage({super.key});

  @override
  State<FeatureFlagsAdminPage> createState() => _FeatureFlagsAdminPageState();
}

class _FeatureFlagsAdminPageState extends State<FeatureFlagsAdminPage> {
  final _service = FeatureFlagService.instance;
  bool _canManage = false;
  bool _loadingPerm = true;
  String? _savingModuleId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.ensureDefaultDocuments();
    final ctx = await RbacService.instance.resolveContext();
    if (mounted) {
      setState(() {
        _canManage = ctx.isFounder ||
            ctx.has(AppPermission.featureFlagsManage) ||
            ctx.has(AppPermission.platformSettings);
        _loadingPerm = false;
      });
    }
  }

  Future<void> _persist(
    FeatureFlagModel previous,
    FeatureFlagModel updated,
  ) async {
    if (!_canManage) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    setState(() => _savingModuleId = updated.id);
    try {
      await _service.saveModule(
        moduleId: updated.id,
        enabled: updated.enabled,
        maintenanceMode: updated.maintenanceMode,
        maintenanceMessage: updated.maintenanceMessage,
        updatedBy: uid,
      );
      await PlatformRegistry.instance.audit.log(
        eventType: AuditEventType.featureFlagUpdated,
        actorUserId: uid,
        entityType: 'feature_flag',
        entityId: updated.id,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'feature_flag.update',
          'blocked': false,
          'reason': 'admin_update',
          'before': {
            'enabled': previous.enabled,
            'maintenanceMode': previous.maintenanceMode,
            'maintenanceMessage': previous.maintenanceMessage,
          },
          'after': {
            'enabled': updated.enabled,
            'maintenanceMode': updated.maintenanceMode,
            'maintenanceMessage': updated.maintenanceMessage,
          },
        },
      );
    } finally {
      if (mounted) setState(() => _savingModuleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPerm) {
      return const MasterAdminModuleScaffold(
        title: 'Feature flags',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canManage) {
      return const MasterAdminModuleScaffold(
        title: 'Feature flags',
        body: Center(
          child: Text('Permissão necessária: feature_flags.manage'),
        ),
      );
    }

    return MasterAdminModuleScaffold(
      title: 'Feature flags',
      subtitle: 'Ativar, desativar ou colocar módulos em manutenção',
      body: StreamBuilder<Map<String, FeatureFlagModel>>(
        stream: _service.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final flags = snapshot.data!;
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Alterações são salvas automaticamente e registradas em '
                  'platform_audit_logs.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ...FeatureModules.all.map((id) {
                final flag = flags[id] ?? FeatureFlagModel.enabledDefault(id);
                return _FlagEditorTile(
                  flag: flag,
                  saving: _savingModuleId == id,
                  onChanged: (updated) => _persist(flag, updated),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _FlagEditorTile extends StatefulWidget {
  const _FlagEditorTile({
    required this.flag,
    required this.saving,
    required this.onChanged,
  });

  final FeatureFlagModel flag;
  final bool saving;
  final ValueChanged<FeatureFlagModel> onChanged;

  @override
  State<_FlagEditorTile> createState() => _FlagEditorTileState();
}

class _FlagEditorTileState extends State<_FlagEditorTile> {
  late bool _enabled;
  late bool _maintenance;
  late TextEditingController _messageCtrl;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _FlagEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flag.id != widget.flag.id ||
        oldWidget.flag.updatedAt != widget.flag.updatedAt) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _enabled = widget.flag.enabled;
    _maintenance = widget.flag.maintenanceMode;
    _messageCtrl = TextEditingController(
      text: widget.flag.maintenanceMessage,
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      widget.flag.copyWith(
        enabled: _enabled,
        maintenanceMode: _maintenance,
        maintenanceMessage: _messageCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    FeatureModules.label(widget.flag.id),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget.saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            Text(
              widget.flag.id,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Módulo ativo'),
              subtitle: const Text('Desligado oculta o acesso no app'),
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                _emit();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo manutenção'),
              subtitle: const Text('Exibe tela de manutenção ao acessar'),
              value: _maintenance,
              onChanged: _enabled
                  ? (v) {
                      setState(() => _maintenance = v);
                      _emit();
                    }
                  : null,
            ),
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mensagem de manutenção',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _emit(),
              onTapOutside: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }
}
