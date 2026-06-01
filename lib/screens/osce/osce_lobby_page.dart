import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics/analytics_events.dart';
import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/osce_models.dart';
import '../../services/osce/osce_room_service.dart';
import '../../widgets/performance/performance_home_section.dart';
import '../../core/feature_flags/feature_modules.dart';
import '../../widgets/feature_flags/feature_gate_page.dart';
import 'osce_station_page.dart';

class OsceLobbyPage extends StatefulWidget {
  final String userId;

  const OsceLobbyPage({super.key, required this.userId});

  @override
  State<OsceLobbyPage> createState() => _OsceLobbyPageState();
}

class _OsceLobbyPageState extends State<OsceLobbyPage> with AnalyticsFeatureTracker {
  final _codeController = TextEditingController();
  final _service = OsceRoomService();
  bool _joining = false;
  bool _creating = false;

  String get _displayName {
    final u = FirebaseAuth.instance.currentUser;
    final name = u?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Participante';
  }

  @override
  void initState() {
    super.initState();
    trackFeatureOnce(
      AnalyticsEvents.osceLobbyOpen,
      userId: widget.userId,
    );
  }

  Future<void> _createRoom({required bool isPublic}) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final result = await _service.createRoom(
        hostId: widget.userId,
        hostDisplayName: _displayName,
        isPublic: isPublic,
      );
      if (!mounted) return;

      if (!isPublic) {
        final code = result.joinCode ?? '';
        await showDialog<void>(
          context: context,
          builder: (ctx) => _PrivateRoomCreatedDialog(
            roomLabel: 'Sala ${result.roomNumber}',
            joinCode: code,
            onEnter: () {
              Navigator.pop(ctx);
              _goToStation(result.roomId);
            },
          ),
        );
      } else {
        _goToStation(result.roomId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar sala: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o código da sala.')),
      );
      return;
    }
    setState(() => _joining = true);
    try {
      final roomId = await _service.joinRoomByCode(
        code: code,
        userId: widget.userId,
        displayName: _displayName,
      );
      if (!mounted) return;
      if (roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sala não encontrada.')),
        );
      } else {
        _goToStation(roomId);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _onEnterRoom(OsceRoomModel room) async {
    if (_joining || _creating) return;

    if (!room.isPublic) {
      final code = await _promptPrivateCode(room);
      if (code == null || !mounted) return;
      setState(() => _joining = true);
      try {
        final ok = await _service.verifyJoinCode(room.id, code);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Código incorreto.')),
            );
          }
          return;
        }
        await _service.joinRoom(
          roomId: room.id,
          userId: widget.userId,
          displayName: _displayName,
          joinCode: code,
        );
        if (mounted) _goToStation(room.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      } finally {
        if (mounted) setState(() => _joining = false);
      }
      return;
    }

    setState(() => _joining = true);
    try {
      await _service.joinRoom(
        roomId: room.id,
        userId: widget.userId,
        displayName: _displayName,
      );
      if (mounted) _goToStation(room.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<String?> _promptPrivateCode(OsceRoomModel room) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${room.displayName} — Privada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Digite o código da sala para entrar.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim().toUpperCase()),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  void _goToStation(String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OsceStationPage(
          userId: widget.userId,
          roomId: roomId,
        ),
      ),
    );
  }

  String _statusLabel(OsceRoomStatus s) {
    switch (s) {
      case OsceRoomStatus.waiting:
        return 'Aguardando';
      case OsceRoomStatus.selectingCase:
        return 'Escolhendo caso';
      case OsceRoomStatus.ready:
        return 'Pronta';
      case OsceRoomStatus.running:
        return 'Em andamento';
      case OsceRoomStatus.evaluating:
        return 'Avaliando';
      case OsceRoomStatus.ended:
        return 'Encerrada';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGatePage(
      moduleId: FeatureModules.osce,
      unavailableTitle: 'Fase Prática',
      builder: (context) => Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Fase Prática'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _creating || _joining
                        ? null
                        : () => _createRoom(isPublic: true),
                    icon: const Icon(Icons.public),
                    label: const Text('Criar Sala Pública'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D9488),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _creating || _joining
                        ? null
                        : () => _createRoom(isPublic: false),
                    icon: const Icon(Icons.lock),
                    label: const Text('Criar Sala Privada'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Código da sala',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _joining || _creating ? null : _joinByCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        child: _joining
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.meeting_room, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    'Salas disponíveis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A8A),
                        ),
                  ),
                ],
              ),
            ),
            StreamBuilder<List<OsceRoomModel>>(
              stream: _service.streamAllOpenRooms(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rooms = snap.data ?? [];
                if (rooms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma sala aberta.\nCrie uma sala pública ou privada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final room = rooms[i];
                    return _RoomCard(
                      room: room,
                      statusLabel: _statusLabel(room.status),
                      onJoin: _joining || _creating
                          ? null
                          : () => _onEnterRoom(room),
                      participantStream:
                          _service.streamParticipantCount(room.id),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: PerformanceHomeSection(userId: widget.userId),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PrivateRoomCreatedDialog extends StatelessWidget {
  final String roomLabel;
  final String joinCode;
  final VoidCallback onEnter;

  const _PrivateRoomCreatedDialog({
    required this.roomLabel,
    required this.joinCode,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final shareMsg = 'Estude OSCE comigo! $roomLabel — código: $joinCode';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('$roomLabel criada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Compartilhe o código com seu grupo:'),
          const SizedBox(height: 16),
          SelectableText(
            joinCode,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareMsg));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mensagem copiada para compartilhar'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Compartilhar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ficar no lobby'),
        ),
        FilledButton(
          onPressed: onEnter,
          child: const Text('Entrar na sala'),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final OsceRoomModel room;
  final String statusLabel;
  final VoidCallback? onJoin;
  final Stream<int> participantStream;

  const _RoomCard({
    required this.room,
    required this.statusLabel,
    required this.onJoin,
    required this.participantStream,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.listTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            if (room.specialty.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                room.specialty,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                StreamBuilder<int>(
                  stream: participantStream,
                  builder: (context, snap) {
                    final n = snap.data ?? room.participantCount;
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('$n online'),
                      ],
                    );
                  },
                ),
                const Spacer(),
                Chip(
                  label: Text(statusLabel, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFE0F2FE),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                ),
                child: const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
