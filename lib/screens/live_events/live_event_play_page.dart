import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_feature_tracker.dart';
import '../../models/live_event_models.dart';
import '../../services/auth/admin_auth_service.dart';
import '../../services/live_event_service.dart';
import 'live_event_eliminated_page.dart';

class LiveEventPlayPage extends StatefulWidget {
  final String eventId;
  final String userId;
  final String displayName;

  const LiveEventPlayPage({
    super.key,
    required this.eventId,
    required this.userId,
    required this.displayName,
  });

  @override
  State<LiveEventPlayPage> createState() => _LiveEventPlayPageState();
}

class _LiveEventPlayPageState extends State<LiveEventPlayPage>
    with SingleTickerProviderStateMixin {
  final LiveEventService _service = LiveEventService();
  Timer? _uiTimer;
  Timer? _revealTimer;
  bool _joining = true;
  bool _isAppAdmin = false;
  LiveEventModel? _latestEvent;
  String? _selectedAlt;
  bool _answered = false;
  bool _processingReveal = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadCoordinatorFlags();
    _join();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> _loadCoordinatorFlags() async {
    final allowed = await AdminAuthService().resolveAccess().then((r) => r.allowed);
    if (mounted) setState(() => _isAppAdmin = allowed);
  }

  bool _canDriveRounds(LiveEventModel event) {
    if (_isAppAdmin) return true;
    return event.isHost(widget.userId);
  }

  Future<void> _join() async {
    try {
      await _service.joinEvent(
        eventId: widget.eventId,
        userId: widget.userId,
        displayName: widget.displayName,
      );
      AnalyticsFeatures.liveEvent(
        userId: widget.userId,
        eventId: widget.eventId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    final event = _latestEvent;
    if (event == null || !_canDriveRounds(event)) return;
    _service.advanceToReveal(widget.eventId);
  }

  Future<void> _afterReveal() async {
    final event = _latestEvent;
    if (event == null || !_canDriveRounds(event)) return;
    if (_processingReveal) return;
    _processingReveal = true;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    await _service.advanceFromReveal(widget.eventId);
    _processingReveal = false;
    if (mounted) {
      setState(() {
        _selectedAlt = null;
        _answered = false;
      });
    }
  }

  Future<void> _submitAnswer(LiveEventModel event) async {
    if (_answered || _selectedAlt == null) return;
    final round = event.currentRound;
    if (round.phase != LiveRoundPhase.question) return;

    setState(() => _answered = true);
    await _service.submitAnswer(
      eventId: widget.eventId,
      userId: widget.userId,
      alternativeId: _selectedAlt!,
      roundIndex: round.index,
    );
  }

  void _checkElimination(LiveEventParticipant? part, LiveEventModel event) {
    if (part == null || !part.isEliminated) return;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveEventEliminatedPage(
          eventId: widget.eventId,
          userId: widget.userId,
          participant: part,
          event: event,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _revealTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_joining) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1220),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return StreamBuilder<LiveEventModel?>(
      stream: _service.streamEvent(widget.eventId),
      builder: (context, eventSnap) {
        final event = eventSnap.data;
        if (event == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B1220),
            body: Center(child: Text('Evento não encontrado', style: TextStyle(color: Colors.white))),
          );
        }
        _latestEvent = event;

        return StreamBuilder<LiveEventParticipant?>(
          stream: _service.streamParticipant(widget.eventId, widget.userId),
          builder: (context, partSnap) {
            final part = partSnap.data;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkElimination(part, event);
            });

            final round = event.currentRound;
            if (round.phase == LiveRoundPhase.reveal &&
                !_processingReveal &&
                _canDriveRounds(event)) {
              _revealTimer ??= Timer(const Duration(milliseconds: 100), () {
                _afterReveal();
              });
            } else if (round.phase != LiveRoundPhase.reveal) {
              _revealTimer?.cancel();
              _revealTimer = null;
            }

            if (event.isEnded || round.phase == LiveRoundPhase.ended) {
              return _endedScaffold(event, part);
            }

            return Scaffold(
              backgroundColor: const Color(0xFF0B1220),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                title: Text(event.title),
                actions: [
                  if (part != null && part.isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: event.gameMode == LiveEventGameMode.lives
                            ? Text(
                                '❤️ ${part.livesRemaining}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )
                            : const Icon(Icons.shield, color: Colors.greenAccent),
                      ),
                    ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _statsBar(event),
                    Expanded(child: _body(event, part)),
                    if (round.phase == LiveRoundPhase.question)
                      _rankingStrip(event),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statsBar(LiveEventModel event) {
    final round = event.currentRound;
    final progress = ((round.index + 1) / 20.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statChip('👥', '${event.participantCount}', 'inscritos'),
              _statChip('⚡', '${event.survivorCount}', 'vivos'),
              _statChip('💀', '${event.eliminatedCount}', 'eliminados'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rodada ${round.index + 1}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String icon, String value, String label) {
    return Column(
      children: [
        Text('$icon $value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
      ],
    );
  }

  Widget _body(LiveEventModel event, LiveEventParticipant? part) {
    final round = event.currentRound;
    final q = round.question;

    if (!event.isLive && round.phase == LiveRoundPhase.lobby) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Aguardando início',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                event.description.isNotEmpty
                    ? event.description
                    : 'Você está inscrito. O evento começará no horário programado.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (event.isLive && round.phase == LiveRoundPhase.lobby) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Regras do evento',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                event.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preparando primeira questão...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (q == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (round.phase == LiveRoundPhase.reveal) {
      return _revealView(event, part, q);
    }

    return _questionView(event, part, q, round);
  }

  Widget _questionView(
    LiveEventModel event,
    LiveEventParticipant? part,
    LiveEventQuestionSnapshot q,
    LiveEventCurrentRound round,
  ) {
    final endsAt = round.endsAt;
    var secondsLeft = event.secondsPerQuestion;
    if (endsAt != null) {
      secondsLeft = endsAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
    }

    return FadeTransition(
      opacity: Tween(begin: 0.92, end: 1.0).animate(_glowCtrl),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: secondsLeft <= 5
                    ? Colors.red.withValues(alpha: 0.25)
                    : const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: secondsLeft <= 5 ? Colors.redAccent : Colors.blueAccent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    '${secondsLeft}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              q.enunciado,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ...q.alternativas.map((alt) {
              final id = alt['id'] ?? '';
              final selected = _selectedAlt == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _answered || part?.isActive != true
                        ? null
                        : () => setState(() => _selectedAlt = id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        alt['texto'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (!_answered && _selectedAlt != null && part?.isActive == true)
                  ? () => _submitAnswer(event)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_answered ? 'Resposta enviada' : 'Confirmar resposta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revealView(
    LiveEventModel event,
    LiveEventParticipant? part,
    LiveEventQuestionSnapshot q,
  ) {
    final round = event.currentRound;
    final correctId = q.corretaId;
    final userCorrect = part?.lastAnswerCorrect == true;
    final total = event.participantCount;
    final correct = round.correctCount;
    final wrong = round.wrongCount + round.skippedCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            userCorrect ? Icons.check_circle : Icons.cancel,
            color: userCorrect ? Colors.greenAccent : Colors.redAccent,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            userCorrect ? 'Você sobreviveu!' : 'Resposta incorreta',
            style: TextStyle(
              color: userCorrect ? Colors.greenAccent : Colors.redAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...q.alternativas.map((alt) {
            final id = alt['id'] ?? '';
            final isCorrect = id == correctId;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.2)
                    : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: isCorrect
                    ? Border.all(color: Colors.greenAccent)
                    : null,
              ),
              child: Text(
                alt['texto'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _revealStat('✅', '$correct', 'acertaram'),
              _revealStat('❌', '$wrong', 'erraram'),
              _revealStat('👥', '$total', 'total'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Próxima questão em instantes...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _revealStat(String icon, String v, String label) {
    return Column(
      children: [
        Text('$icon $v', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _rankingStrip(LiveEventModel event) {
    return SizedBox(
      height: 120,
      child: StreamBuilder<List<LiveEventParticipant>>(
        stream: _service.streamTopRanking(widget.eventId),
        builder: (context, snap) {
          final list = (snap.data ?? []).take(10).toList();
          return Container(
            color: const Color(0xFF111827),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                final isMe = p.userId == widget.userId;
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${i + 1}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        '${p.correctAnswers} acertos',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _endedScaffold(LiveEventModel event, LiveEventParticipant? part) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Evento encerrado',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (part?.finalRank != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Sua posição: #${part!.finalRank}',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                Text(
                  '+${part.xpEarned} XP',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
