import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../application/commercial/commercial_admin_service.dart';
import '../../application/platform/platform_registry.dart';
import '../../core/commercial/commercial_entitlement.dart';
import '../../domain/platform/models/affiliate.dart';
import '../../domain/platform/models/seller.dart';
import '../../domain/platform/models/subscription_plan.dart';

/// Bottom sheet para conceder ou revogar acesso manualmente.
class MasterAdminGrantAccessSheet extends StatefulWidget {
  const MasterAdminGrantAccessSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MasterAdminGrantAccessSheet(),
    );
  }

  @override
  State<MasterAdminGrantAccessSheet> createState() =>
      _MasterAdminGrantAccessSheetState();
}

class _MasterAdminGrantAccessSheetState extends State<MasterAdminGrantAccessSheet> {
  final _userIdCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CommercialGrantSource _grantSource = CommercialGrantSource.manual;
  String? _planId;
  String? _sellerId;
  String? _affiliateId;
  DateTime? _expiresAt;
  bool _saving = false;
  bool _revoking = false;

  List<SubscriptionPlan> _plans = [];
  List<Seller> _sellers = [];
  List<Affiliate> _affiliates = [];

  CommercialAdminService get _admin => PlatformRegistry.instance.commercialAdmin;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final repos = PlatformRegistry.instance.repositories;
    final plans = await repos.subscriptionPlans.watchAllPlans().first;
    final sellers = await repos.sellers.watchAll(activeOnly: false).first;
    final affiliates = await repos.affiliates.watchAll(activeOnly: false).first;
    if (mounted) {
      setState(() {
        _plans = plans;
        _sellers = sellers;
        _affiliates = affiliates;
        _planId = plans.isNotEmpty ? plans.first.id : null;
      });
    }
  }

  CommercialEntitlementKey _entitlementForSource() {
    switch (_grantSource) {
      case CommercialGrantSource.lifetime:
        return CommercialEntitlementKey.premiumLifetime;
      case CommercialGrantSource.courtesy:
        return CommercialEntitlementKey.courtesyAccess;
      case CommercialGrantSource.beta:
        return CommercialEntitlementKey.betaTester;
      default:
        return CommercialEntitlementKey.premium;
    }
  }

  Future<void> _grant() async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) {
      _snack('Informe o userId do aluno.');
      return;
    }
    final actor = FirebaseAuth.instance.currentUser?.uid;
    if (actor == null) {
      _snack('Admin não autenticado.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _admin.grantAccess(
        actorUserId: actor,
        targetUserId: userId,
        grantSource: _grantSource,
        entitlementKey: _entitlementForSource(),
        planId: _planId,
        expiresAt: _grantSource == CommercialGrantSource.lifetime ? null : _expiresAt,
        sellerId: _sellerId,
        affiliateId: _affiliateId,
        couponCode: _couponCtrl.text.trim().isEmpty ? null : _couponCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso concedido com sucesso.')),
        );
      }
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke() async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) {
      _snack('Informe o userId do aluno.');
      return;
    }
    final actor = FirebaseAuth.instance.currentUser?.uid;
    if (actor == null) return;

    setState(() => _revoking = true);
    try {
      await _admin.revokeAccess(
        actorUserId: actor,
        targetUserId: userId,
        reason: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso revogado.')),
        );
      }
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _couponCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Conceder / revogar acesso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdCtrl,
              decoration: const InputDecoration(
                labelText: 'User ID (Firebase Auth UID)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CommercialGrantSource>(
              initialValue: _grantSource,
              decoration: const InputDecoration(
                labelText: 'Tipo de concessão',
                border: OutlineInputBorder(),
              ),
              items: CommercialGrantSource.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _grantSource = v!),
            ),
            const SizedBox(height: 12),
            if (_plans.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _planId,
                decoration: const InputDecoration(
                  labelText: 'Plano',
                  border: OutlineInputBorder(),
                ),
                items: _plans
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => _planId = v),
              ),
            const SizedBox(height: 12),
            if (_grantSource != CommercialGrantSource.lifetime)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data de expiração (opcional)'),
                subtitle: Text(
                  _expiresAt == null
                      ? 'Sem data definida'
                      : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _expiresAt = picked);
                  },
                ),
              ),
            if (_sellers.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _sellerId,
                decoration: const InputDecoration(
                  labelText: 'Vendedor (opcional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Nenhum —')),
                  ..._sellers.map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.displayName.isNotEmpty ? s.displayName : s.id),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _sellerId = v),
              ),
            ],
            if (_affiliates.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _affiliateId,
                decoration: const InputDecoration(
                  labelText: 'Afiliado (opcional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Nenhum —')),
                  ..._affiliates.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.code)),
                  ),
                ],
                onChanged: (v) => setState(() => _affiliateId = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _couponCtrl,
              decoration: const InputDecoration(
                labelText: 'Cupom (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _grant,
              child: Text(_saving ? 'Concedendo...' : 'Conceder acesso'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _revoking ? null : _revoke,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: Text(_revoking ? 'Revogando...' : 'Revogar acesso'),
            ),
          ],
        ),
      ),
    );
  }
}
