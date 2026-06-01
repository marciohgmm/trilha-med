import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../application/platform/platform_registry.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/push/push_notification_types.dart';
import '../../../domain/platform/models/push_campaign.dart';
import '../../../widgets/master_admin/master_admin_diagnostics_panel.dart';
import '../../../widgets/master_admin/master_admin_module_scaffold.dart';

class MasterAdminPushPage extends StatefulWidget {
  const MasterAdminPushPage({super.key});

  @override
  State<MasterAdminPushPage> createState() => _MasterAdminPushPageState();
}

class _MasterAdminPushPageState extends State<MasterAdminPushPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _eventId = TextEditingController();

  String _type = PushNotificationType.adminBroadcast;
  String _segment = PushAudienceSegment.all;
  String? _actionRoute;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _eventId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha título e mensagem.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await PlatformRegistry.instance.pushCampaignAdmin.createAndSendCampaign(
        title: title,
        body: body,
        type: _type,
        audienceSegment: _segment,
        eventId: _segment == PushAudienceSegment.liveEventAudience
            ? _eventId.text.trim()
            : null,
        actionRoute: _actionRoute,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campanha enfileirada. O envio ocorre em segundo plano.'),
        ),
      );
      _title.clear();
      _body.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterAdminModuleScaffold(
      title: 'Push notifications',
      subtitle: 'Envio segmentado via FCM',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComposer(),
          const SizedBox(height: 32),
          const Text(
            'Histórico de campanhas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: PushNotificationType.all
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(PushNotificationType.label(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _segment,
              decoration: const InputDecoration(
                labelText: 'Público',
                border: OutlineInputBorder(),
              ),
              items: PushAudienceSegment.options
                  .map(
                    (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _segment = v ?? _segment),
            ),
            if (_segment == PushAudienceSegment.liveEventAudience) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _eventId,
                decoration: const InputDecoration(
                  labelText: 'ID do evento ao vivo',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _actionRoute,
              decoration: const InputDecoration(
                labelText: 'Ação ao tocar (opcional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Padrão pelo tipo')),
                DropdownMenuItem(value: 'simulado', child: Text('Simulados')),
                DropdownMenuItem(value: 'osce', child: Text('OSCE')),
                DropdownMenuItem(value: 'plans', child: Text('Planos')),
                DropdownMenuItem(
                  value: 'subscription',
                  child: Text('Minha assinatura'),
                ),
                DropdownMenuItem(
                  value: 'live_event',
                  child: Text('Evento ao vivo'),
                ),
              ],
              onChanged: (v) => setState(() => _actionRoute = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Enviando…' : 'Enviar campanha'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.platformPushCampaigns)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return MasterAdminModuleErrorView(error: snap.error);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text(
            'Nenhuma campanha enviada ainda.',
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Column(
          children: docs.map((d) {
            final c = PushCampaign.fromDoc(d.id, d.data());
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.title),
              subtitle: Text(
                '${PushNotificationType.label(c.type)} · ${c.audienceSegment}\n'
                'Status: ${c.status} · Enviados: ${c.sentCount} · Falhas: ${c.failureCount}',
              ),
              isThreeLine: true,
            );
          }).toList(),
        );
      },
    );
  }
}
