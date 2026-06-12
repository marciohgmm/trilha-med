import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../application/rbac/rbac_service.dart';
import '../../../core/access/app_access_feature.dart';
import '../../../core/audit/audit_event_type.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../data/app_access_default_seed.dart';
import '../../../data/commercial_plan_catalog.dart';
import '../../../models/app_access_config_model.dart';
import '../../../services/access/app_access_config_service.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

/// Painel: gratuito vs premium — `app_access_config/plans`.
class AppAccessConfigAdminPage extends StatefulWidget {
  const AppAccessConfigAdminPage({super.key});

  @override
  State<AppAccessConfigAdminPage> createState() =>
      _AppAccessConfigAdminPageState();
}

class _AppAccessConfigAdminPageState extends State<AppAccessConfigAdminPage> {
  final _configService = AppAccessConfigService.instance;
  bool _canManage = false;
  bool _loadingPerm = true;
  bool _saving = false;
  AppAccessConfigModel? _draft;
  bool _dirty = false;

  final _limitControllers = <AppAccessFeature, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final f in AppAccessFeature.adminLimitFeatures) {
      _limitControllers[f] = TextEditingController();
    }
    _init();
  }

  @override
  void dispose() {
    for (final c in _limitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    await _configService.ensureDefaultDocument();
    final ctx = await RbacService.instance.resolveContext();
    if (mounted) {
      setState(() {
        _canManage = ctx.isFounder ||
            ctx.has(AppPermission.platformSettings) ||
            ctx.has(AppPermission.subscriptionManage);
        _loadingPerm = false;
      });
    }
  }

  void _loadDraft(AppAccessConfigModel source) {
    _draft = source;
    _dirty = false;
    for (final f in AppAccessFeature.adminLimitFeatures) {
      final limit = source.free.limitFor(f);
      _limitControllers[f]!.text = '${limit ?? 0}';
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  AppAccessConfigModel get _working =>
      _draft ?? AppAccessDefaultSeed.defaults();

  void _setFreeEnabled(AppAccessFeature feature, bool value) {
    setState(() {
      _draft = _working.copyWith(
        free: _working.free.setFeatureEnabled(feature, value),
      );
      _dirty = true;
    });
  }

  void _setPremiumEnabled(AppAccessFeature feature, bool value) {
    setState(() {
      _draft = _working.copyWith(
        premium: _working.premium.setFeatureEnabled(feature, value),
      );
      _dirty = true;
    });
  }

  void _setDisplay({bool? padlock, bool? upgrade, bool? enforcement}) {
    setState(() {
      _draft = _working.copyWith(
        showLockedWithPadlock: padlock ?? _working.showLockedWithPadlock,
        showUpgradeButton: upgrade ?? _working.showUpgradeButton,
        accessEnforcementEnabled:
            enforcement ?? _working.accessEnforcementEnabled,
      );
      _dirty = true;
    });
  }

  void _applyLimitsFromFields() {
    var free = _working.free;
    for (final f in AppAccessFeature.adminLimitFeatures) {
      final raw = _limitControllers[f]!.text.trim();
      final parsed = int.tryParse(raw) ?? 0;
      free = free.setFeatureLimit(f, parsed < 0 ? 0 : parsed);
    }
    setState(() {
      _draft = _working.copyWith(free: free);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_canManage || _draft == null) return;
    _applyLimitsFromFields();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    setState(() => _saving = true);
    try {
      await _configService.save(_draft!, updatedBy: uid);
      await PlatformRegistry.instance.audit.log(
        eventType: AuditEventType.accessConfigUpdated,
        actorUserId: uid,
        entityType: 'app_access_config',
        entityId: AppAccessConfigModel.documentId,
        metadata: {
          'action': 'app_access_config.update',
          'free': _draft!.free.toMap(),
          'premium': _draft!.premium.toMap(),
          'display': {
            'showLockedWithPadlock': _draft!.showLockedWithPadlock,
            'showUpgradeButton': _draft!.showUpgradeButton,
          },
        },
      );
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuração de acesso salva com sucesso.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPerm) {
      return const MasterAdminModuleScaffold(
        title: 'Plano gratuito vs Premium',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canManage) {
      return const MasterAdminModuleScaffold(
        title: 'Plano gratuito vs Premium',
        body: Center(
          child: Text('Permissão necessária: platform.settings'),
        ),
      );
    }

    return MasterAdminModuleScaffold(
      title: 'Plano gratuito vs Premium',
      subtitle:
          'Marque o que fica liberado no gratuito. Usuários Premium usam a coluna Premium.',
      actions: [
        if (_dirty)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _draft = null;
                      _dirty = false;
                    });
                  },
            icon: const Icon(Icons.undo),
            label: const Text('Descartar'),
          ),
        FilledButton.icon(
          onPressed: _saving || !_dirty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Salvando…' : 'Salvar'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: StreamBuilder<AppAccessConfigModel>(
        stream: _configService.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_draft == null || (!_dirty && !_saving)) {
            _loadDraft(snapshot.data!);
          }

          final cfg = _working;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _infoBanner(),
              const SizedBox(height: 16),
              _sectionTitle('Funcionalidades — plano gratuito'),
              const SizedBox(height: 8),
              const Text(
                'Marque o que usuários sem Premium podem usar.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...AppAccessFeature.adminFeatures.map(
                (f) => _FreeFeatureCheckbox(
                  feature: f,
                  enabled: cfg.free.isFeatureEnabled(f),
                  onChanged: (v) => _setFreeEnabled(f, v),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Funcionalidades — plano Premium'),
              const SizedBox(height: 8),
              const Text(
                'Normalmente tudo ligado. Desligue apenas se quiser restringir Premium.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...AppAccessFeature.adminFeatures.map(
                (f) => _PremiumFeatureCheckbox(
                  feature: f,
                  enabled: cfg.premium.isFeatureEnabled(f),
                  onChanged: (v) => _setPremiumEnabled(f, v),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Limites do plano gratuito'),
              const SizedBox(height: 8),
              const Text(
                'Use 0 para desabilitar o recurso no gratuito. '
                'Premium com 0 = ilimitado.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...AppAccessFeature.adminLimitFeatures.map(
                (f) => _LimitField(
                  feature: f,
                  controller: _limitControllers[f]!,
                  onChanged: _markDirty,
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Enforcement P0'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: cfg.accessEnforcementEnabled,
                onChanged: _canManage
                    ? (v) => _setDisplay(enforcement: v ?? false)
                    : null,
                title: const Text('Ativar limites do plano gratuito no app'),
                subtitle: const Text(
                  'Quando desligado (padrão), flashcards e questões ficam '
                  'sem bloqueio por cota — útil para rollout gradual.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              _sectionTitle('Aparência do bloqueio'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: cfg.showLockedWithPadlock,
                onChanged: (v) => _setDisplay(padlock: v ?? true),
                title: const Text('Mostrar conteúdo bloqueado com cadeado'),
                subtitle: const Text(
                  'Exibe ícone de cadeado nas telas bloqueadas (AccessGate)',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: cfg.showUpgradeButton,
                onChanged: (v) => _setDisplay(upgrade: v ?? true),
                title: const Text('Mostrar botão de upgrade para Premium'),
                subtitle: const Text('Botão “Assinar Premium” nas telas bloqueadas'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              _previewCard(cfg),
            ],
          );
        },
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Text(
        'Salvo em Firestore: app_access_config/plans. '
        'A tabela "Compare os planos" na tela Planos Premium do app usa estas '
        'marcas (Gratuito vs Premium). AccessGate controla o acesso real nas telas.',
        style: TextStyle(fontSize: 13, height: 1.45),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _previewCard(AppAccessConfigModel cfg) {
    final rows = CommercialPlanCatalog.comparisonForDisplay(
      accessConfig: cfg,
      premiumPlan: null,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prévia — tabela na tela Planos Premium',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ex.: Ferramentas médicas só no Gratuito = ✓ na coluna Gratuito e ✗ no Premium.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Color(0xFFE2E8F0)),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Benefício', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Grat.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Prem.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...rows.map((row) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(row.benefit, style: const TextStyle(fontSize: 12)),
                      ),
                      _previewCell(row.includedInFree, row.freeText),
                      _previewCell(row.includedInPremium, row.premiumText),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCell(bool included, String? text) {
    if (text != null && text.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: included ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        included ? Icons.check_circle : Icons.remove_circle_outline,
        color: included ? const Color(0xFF059669) : const Color(0xFF94A3B8),
        size: 20,
      ),
    );
  }
}

class _FreeFeatureCheckbox extends StatelessWidget {
  const _FreeFeatureCheckbox({
    required this.feature,
    required this.enabled,
    required this.onChanged,
  });

  final AppAccessFeature feature;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: enabled,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(feature.label),
        subtitle: Text('Liberado no gratuito · ${feature.enabledField}'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _PremiumFeatureCheckbox extends StatelessWidget {
  const _PremiumFeatureCheckbox({
    required this.feature,
    required this.enabled,
    required this.onChanged,
  });

  final AppAccessFeature feature;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF8FAFC),
      child: CheckboxListTile(
        value: enabled,
        onChanged: (v) => onChanged(v ?? false),
        title: Text('${feature.label} (Premium)'),
        subtitle: Text(feature.enabledField),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField({
    required this.feature,
    required this.controller,
    required this.onChanged,
  });

  final AppAccessFeature feature;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Limite gratuito — ${feature.label}',
            hintText: '0 = ilimitado',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }
}
