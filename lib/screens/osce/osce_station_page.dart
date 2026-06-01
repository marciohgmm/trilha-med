import 'package:flutter/material.dart';

import '../../core/analytics/analytics_events.dart';
import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/osce_models.dart';
import '../../services/osce/osce_room_service.dart';
import '../../models/osce_script_fields.dart';
import '../../widgets/osce/osce_rich_content_view.dart';
import '../../widgets/osce/osce_evaluated_live_score_bar.dart';
import '../../widgets/osce/osce_scroll_physics.dart';
import '../../widgets/osce/osce_station_timer_bar.dart';
import '../../services/osce/osce_evaluation_service.dart';
import 'osce_evaluation_page.dart';

class OsceStationPage extends StatefulWidget {
  final String userId;
  final String roomId;

  const OsceStationPage({
    super.key,
    required this.userId,
    required this.roomId,
  });

  @override
  State<OsceStationPage> createState() => _OsceStationPageState();
}

class _OsceStationPageState extends State<OsceStationPage> with AnalyticsFeatureTracker {
  final _service = OsceRoomService();
  OsceCaseModel? _case;
  String? _loadedCaseId;
  bool _timerEndHandled = false;
  bool _evaluationNavHandled = false;
  final _evalService = OsceEvaluationService();
  String? _selectedSpecialty = OsceSpecialties.allLabel;

  @override
  void initState() {
    super.initState();
    trackFeatureOnce(
      AnalyticsEvents.osceStationStart,
      userId: widget.userId,
      parameters: {AnalyticsParams.roomId: widget.roomId},
    );
  }

  Future<void> _loadCase(String? caseId) async {
    if (caseId == null || caseId == _loadedCaseId) return;
    _loadedCaseId = caseId;
    final c = await _service.getCase(caseId);
    if (mounted) setState(() => _case = c);
  }

  Future<void> _leaveStation() async {
    await _service.leaveRoom(widget.roomId, widget.userId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _endStation(
    OsceRoomModel room,
    List<OsceParticipantModel> participants,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar estação?'),
        content: const Text(
          'Todos irão para a tela de avaliação. Marque os itens e finalize '
          'para salvar a nota do médico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Ir para avaliação'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _openEvaluation(room, participants);
    }
  }

  Future<void> _openEvaluation(
    OsceRoomModel room,
    List<OsceParticipantModel> participants,
  ) async {
    final caseModel = _case;
    if (caseModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um caso antes de avaliar.')),
        );
      }
      return;
    }

    String evaluatorName = 'Avaliador';
    String evaluatedName = 'Médico';
    for (final p in participants) {
      if (p.userId == room.evaluatorUserId) evaluatorName = p.displayName;
      if (p.userId == room.evaluatedUserId) evaluatedName = p.displayName;
    }

    try {
      final evalId = await _evalService.beginEvaluationForRoom(
        room: room,
        caseModel: caseModel,
        evaluatorId: room.evaluatorUserId!,
        evaluatorName: evaluatorName,
        evaluatedName: evaluatedName,
      );
      if (!mounted) return;
      _evaluationNavHandled = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OsceEvaluationPage(
            userId: widget.userId,
            roomId: widget.roomId,
            evaluationId: evalId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onRoomEvaluating(OsceRoomModel room) {
    if (room.status != OsceRoomStatus.evaluating) return;
    final evalId = room.evaluationId;
    if (evalId == null || evalId.isEmpty || _evaluationNavHandled) return;
    _evaluationNavHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OsceEvaluationPage(
            userId: widget.userId,
            roomId: widget.roomId,
            evaluationId: evalId,
          ),
        ),
      );
    });
  }

  void _onRoomEnded(OsceRoomModel room) {
    if (room.status == OsceRoomStatus.ended && mounted && !_evaluationNavHandled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão encerrada.')),
        );
        Navigator.pop(context);
      });
    }
  }

  String _statusLabel(OsceRoomStatus s) {
    switch (s) {
      case OsceRoomStatus.waiting:
        return 'Aguardando participantes';
      case OsceRoomStatus.selectingCase:
        return 'Escolhendo caso';
      case OsceRoomStatus.ready:
        return 'Pronta para iniciar';
      case OsceRoomStatus.running:
        return 'Estação em andamento';
      case OsceRoomStatus.evaluating:
        return 'Avaliação em andamento';
      case OsceRoomStatus.ended:
        return 'Encerrada';
    }
  }

  Future<void> _pickCase(OsceRoomModel room) async {
    final cases = await _service
        .streamCases(specialtyFilter: _selectedSpecialty)
        .first;
    if (!mounted) return;
    if (cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum caso para esta especialidade.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<OsceCaseModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Selecionar caso clínico',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: cases.length,
                itemBuilder: (_, i) {
                  final c = cases[i];
                  return ListTile(
                    title: Text(c.title),
                    subtitle: Text(c.specialty),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _service.selectCase(widget.roomId, picked.id, picked.specialty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use "Sair da estação" para voltar ao lobby.'),
            ),
          );
        }
      },
      child: StreamBuilder<OsceRoomModel?>(
        stream: _service.streamRoom(widget.roomId),
        builder: (context, roomSnap) {
          final room = roomSnap.data;
          if (room == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          _loadCase(room.caseId);
          _onRoomEvaluating(room);
          _onRoomEnded(room);

          return StreamBuilder<List<OsceParticipantModel>>(
            stream: _service.streamParticipants(widget.roomId),
            builder: (context, partSnap) {
              final participants = partSnap.data ?? [];
              final role = _service.effectiveRole(
                room,
                widget.userId,
                participants,
              );
              final isEvaluator = _service.isEvaluator(room, widget.userId);
              final isEvaluated = _service.isEvaluated(room, widget.userId);

              return Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.displayName,
                        style: const TextStyle(fontSize: 18),
                      ),
                      Text(
                        room.typeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  actions: [
                    if (isEvaluator)
                      IconButton(
                        tooltip: 'Encerrar estação',
                        onPressed: () => _endStation(room, participants),
                        icon: const Icon(Icons.stop_circle_outlined),
                      ),
                    TextButton(
                      onPressed: _leaveStation,
                      child: const Text(
                        'Sair',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                body: SafeArea(
                  top: false,
                  child: CustomScrollView(
                    physics: OsceScrollPhysics.list,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: OsceStationTimerBar(
                          room: room,
                          onTimerEnded:
                              room.stationStarted && !_timerEndHandled
                                  ? () {
                                      _timerEndHandled = true;
                                      if (isEvaluator) {
                                        _openEvaluation(room, participants);
                                      }
                                    }
                                  : null,
                        ),
                      ),
                      if (room.status == OsceRoomStatus.evaluating &&
                          isEvaluated &&
                          room.evaluationId != null)
                        SliverToBoxAdapter(
                          child: OsceEvaluatedLiveScoreBar(
                            evaluationId: room.evaluationId,
                            onOpenFullEvaluation: () {
                              _evaluationNavHandled = true;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OsceEvaluationPage(
                                    userId: widget.userId,
                                    roomId: widget.roomId,
                                    evaluationId: room.evaluationId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _RoleBanner(
                          role: role,
                          status: _statusLabel(room.status),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _ParticipantsPanel(
                          room: room,
                          participants: participants,
                          userId: widget.userId,
                          service: _service,
                          initiallyExpanded: !room.stationStarted,
                          canManageRoles:
                              isEvaluator && !room.stationStarted,
                          canAssumeDoctor:
                              !room.stationStarted && !isEvaluated,
                          onAssumeDoctor: () => _service.assumeEvaluated(
                            widget.roomId,
                            widget.userId,
                          ),
                          onAssumeEvaluator: () => _service.assumeEvaluator(
                            widget.roomId,
                            widget.userId,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            isEvaluated
                                ? _EvaluatedBody.buildContent(
                                    room: room,
                                    caseModel: _case,
                                    onStart: () => _service.startStation(
                                      widget.roomId,
                                      widget.userId,
                                    ),
                                  )
                                : _StaffBody.buildContent(
                                    room: room,
                                    caseModel: _case,
                                    isEvaluator: isEvaluator,
                                    selectedSpecialty: _selectedSpecialty,
                                    onSpecialtyChanged: (s) => setState(
                                      () => _selectedSpecialty = s,
                                    ),
                                    onPickCase: () => _pickCase(room),
                                    onRelease: (t) =>
                                        _service.releaseExam(
                                          widget.roomId,
                                          t,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 32),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  final OsceParticipantRole role;
  final String status;

  const _RoleBanner({required this.role, required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (role) {
      case OsceParticipantRole.evaluator:
        icon = Icons.theater_comedy;
        color = const Color(0xFF0D9488);
        break;
      case OsceParticipantRole.evaluated:
        icon = Icons.medical_services;
        color = const Color(0xFF1E3A8A);
        break;
      case OsceParticipantRole.spectator:
        icon = Icons.visibility;
        color = Colors.grey.shade700;
        break;
    }
    final safe = MediaQuery.paddingOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16 + safe.left,
        10,
        16 + safe.right,
        10,
      ),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            'Seu papel: ${role.label}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const Spacer(),
          Chip(
            label: Text(status, style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ParticipantsPanel extends StatelessWidget {
  final OsceRoomModel room;
  final List<OsceParticipantModel> participants;
  final String userId;
  final OsceRoomService service;
  final bool initiallyExpanded;
  final bool canManageRoles;
  final bool canAssumeDoctor;
  final VoidCallback onAssumeDoctor;
  final VoidCallback onAssumeEvaluator;

  const _ParticipantsPanel({
    required this.room,
    required this.participants,
    required this.userId,
    required this.service,
    this.initiallyExpanded = true,
    required this.canManageRoles,
    required this.canAssumeDoctor,
    required this.onAssumeDoctor,
    required this.onAssumeEvaluator,
  });

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Card(
      margin: EdgeInsets.fromLTRB(
        12 + safe.left,
        4,
        12 + safe.right,
        4,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        title: Text(
          'Participantes (${participants.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: room.stationStarted
            ? const Text(
                'Toque para expandir',
                style: TextStyle(fontSize: 12),
              )
            : null,
        children: [
          ...participants.map((p) {
              final isDoc = room.evaluatedUserId == p.userId;
              final isEval = room.evaluatorUserId == p.userId;
              String badge = p.role.label;
              if (isDoc) badge = 'Médico avaliado';
              if (isEval) badge = 'Avaliador';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.displayName),
                subtitle: Text(badge),
                trailing: canManageRoles && p.userId != userId
                    ? PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            if (v == 'doctor') {
                              await service.assignEvaluated(
                                room.id,
                                p.userId,
                                userId,
                              );
                            } else if (v == 'evaluator') {
                              await service.assignEvaluator(
                                room.id,
                                p.userId,
                                userId,
                              );
                            } else if (v == 'remove_doctor' && isDoc) {
                              await service.clearEvaluated(room.id, userId);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'doctor',
                            child: Text('Definir como médico'),
                          ),
                          const PopupMenuItem(
                            value: 'evaluator',
                            child: Text('Definir como avaliador'),
                          ),
                          if (isDoc)
                            const PopupMenuItem(
                              value: 'remove_doctor',
                              child: Text('Remover médico'),
                            ),
                        ],
                      )
                    : null,
              );
            }),
          if (!room.stationStarted) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (room.evaluatorUserId == null)
                  OutlinedButton.icon(
                    onPressed: onAssumeEvaluator,
                    icon: const Icon(Icons.theater_comedy, size: 18),
                    label: const Text('Assumir papel de Avaliador'),
                  ),
                if (canAssumeDoctor)
                  FilledButton.icon(
                    onPressed: onAssumeDoctor,
                    icon: const Icon(Icons.medical_services, size: 18),
                    label: const Text('Assumir papel de Médico'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Médico avaliado — visão limitada
// ---------------------------------------------------------------------------

class _EvaluatedBody {
  _EvaluatedBody._();

  static List<Widget> buildContent({
    required OsceRoomModel room,
    required OsceCaseModel? caseModel,
    required VoidCallback onStart,
  }) {
    final c = caseModel;
    final canStart =
        !room.stationStarted && room.caseId != null && room.caseId!.isNotEmpty;
    final widgets = <Widget>[];

    if (canStart) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar Estação'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      );
    }

    if (c == null) {
      widgets.add(
        const _OsceCard(
          title: 'AGUARDANDO',
          body: 'O avaliador ainda não selecionou o caso clínico.',
        ),
      );
    } else {
      widgets.addAll([
        _OsceCard(
          title: 'CENÁRIO DE ATENDIMENTO',
          child: OsceRichContentView(content: c.scenario),
        ),
        _OsceCard(
          title: 'TAREFAS',
          child: OsceRichContentView(content: c.tasks),
        ),
        if (room.physicalExam.released)
          _OsceCard(
            title: 'EXAME FÍSICO',
            child: OsceRichContentView(content: c.physicalExamContent),
          ),
        if (room.laboratoryExam.released)
          _OsceCard(
            title: 'LABORATÓRIO',
            child: OsceRichContentView(content: c.laboratoryContent),
          ),
        if (room.imagingExam.released)
          _OsceCard(
            title: 'IMAGEM',
            child: OsceRichContentView(
              content: c.imagingContent,
              imageUrl: c.imagingImageUrl,
            ),
          ),
      ]);
    }

    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Avaliador + Telespectadores — visão completa
// ---------------------------------------------------------------------------

class _StaffBody {
  _StaffBody._();

  static List<Widget> buildContent({
    required OsceRoomModel room,
    required OsceCaseModel? caseModel,
    required bool isEvaluator,
    required String? selectedSpecialty,
    required ValueChanged<String?> onSpecialtyChanged,
    required VoidCallback onPickCase,
    required void Function(OsceExamType) onRelease,
  }) {
    final c = caseModel;
    final widgets = <Widget>[];

    if (isEvaluator && !room.stationStarted) {
      widgets.addAll([
            const Text(
              'Escolher tema do caso',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecione a especialidade e depois o caso clínico para esta sala.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'Especialidade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...OsceSpecialties.list,
                OsceSpecialties.allLabel,
              ].map((s) {
                final selected = selectedSpecialty == s;
                return FilterChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (_) => onSpecialtyChanged(s),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onPickCase,
              icon: const Icon(Icons.menu_book),
              label: Text(
                room.caseId == null
                    ? 'Selecionar caso clínico'
                    : 'Trocar caso clínico',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
              ),
            ),
        const SizedBox(height: 16),
      ]);
    }

    if (c == null) {
      widgets.add(
        const _OsceCard(
          title: 'SCRIPT',
          body: 'Aguardando seleção do caso pelo avaliador.',
        ),
      );
    } else {
      for (final f in OsceScriptFields.fieldDefs) {
        final body = c.actorScript[f.key] ?? '';
        if (body.trim().isEmpty) continue;
        widgets.add(
          _OsceCard(
            title: f.label.toUpperCase(),
            child: OsceRichContentView(content: body),
          ),
        );
      }
      widgets.addAll([
        _OsceCard(
          title: 'CENÁRIO',
          child: OsceRichContentView(content: c.scenario),
        ),
        _OsceCard(
          title: 'DESCRIÇÃO DO CASO',
          child: OsceRichContentView(content: c.caseDescription),
        ),
        if (c.hiddenDiagnosis.isNotEmpty)
          _OsceCard(
            title: 'DIAGNÓSTICO',
            accent: const Color(0xFFDC2626),
            child: OsceRichContentView(content: c.hiddenDiagnosis),
          ),
        const Text(
          'Exames',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        _StaffExamTile(
          label: 'Exame físico',
          slot: room.physicalExam,
          content: c.physicalExamContent,
          canRelease: isEvaluator,
          onRelease: () => onRelease(OsceExamType.physical),
        ),
        _StaffExamTile(
          label: 'Laboratório',
          slot: room.laboratoryExam,
          content: c.laboratoryContent,
          canRelease: isEvaluator,
          onRelease: () => onRelease(OsceExamType.laboratory),
        ),
        _StaffExamTile(
          label: 'Imagem',
          slot: room.imagingExam,
          content: c.imagingContent,
          imageUrl: c.imagingImageUrl,
          canRelease: isEvaluator,
          onRelease: () => onRelease(OsceExamType.imaging),
        ),
      ]);
    }

    return widgets;
  }
}

class _StaffExamTile extends StatelessWidget {
  final String label;
  final OsceExamSlot slot;
  final String content;
  final String? imageUrl;
  final bool canRelease;
  final VoidCallback onRelease;

  const _StaffExamTile({
    required this.label,
    required this.slot,
    required this.content,
    this.imageUrl,
    required this.canRelease,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          slot.released
              ? 'Liberado — visível ao médico'
              : 'Oculto para o médico (libere após solicitação verbal)',
        ),
        children: [
          if (slot.released)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: content.isEmpty && (imageUrl == null || imageUrl!.isEmpty)
                  ? const Text('—')
                  : OsceRichContentView(content: content, imageUrl: imageUrl),
            ),
          if (canRelease && !slot.released)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRelease,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                  child: const Text('Liberar exame'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OsceCard extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? child;
  final Color? accent;

  const _OsceCard({
    required this.title,
    this.body,
    this.child,
    this.accent,
  }) : assert(body != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accent ?? const Color(0xFF0D9488),
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            if (child != null)
              child!
            else
              Text(body!, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}
