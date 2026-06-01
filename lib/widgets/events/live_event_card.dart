import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/live_event_models.dart';
import '../../screens/live_events/live_event_play_page.dart';

/// Card premium horizontal para um evento ao vivo.
class LiveEventCard extends StatefulWidget {
  final LiveEventModel event;
  final String userId;
  final String displayName;
  final double width;

  const LiveEventCard({
    super.key,
    required this.event,
    required this.userId,
    required this.displayName,
    this.width = 300,
  });

  @override
  State<LiveEventCard> createState() => _LiveEventCardState();
}

class _LiveEventCardState extends State<LiveEventCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _countdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return '00h 00m';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  String _weekday(DateTime d) {
    const names = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    return names[d.weekday - 1];
  }

  void _openEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveEventPlayPage(
          eventId: widget.event.id,
          userId: widget.userId,
          displayName: widget.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final display = event.displayStatus;
    final isLive = display == LiveEventStatus.live;
    final isEnded = display == LiveEventStatus.ended;

    final gradient = isLive
        ? const [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFEA580C)]
        : isEnded
            ? [Color(0xFF1F2937), Color(0xFF374151)]
            : [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF312E81)];

    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isLive ? Colors.red : const Color(0xFF1E3A8A))
                .withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnded ? null : _openEvent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.red, size: 10),
                            SizedBox(width: 6),
                            Text(
                              'AO VIVO AGORA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (display == LiveEventStatus.upcoming)
                      Text(
                        'EM BREVE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      '${event.type.emoji} ${event.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isLive && !isEnded) ...[
                      Text(
                        '${_weekday(event.scheduledAt)} • '
                        '${event.scheduledAt.hour.toString().padLeft(2, '0')}:'
                        '${event.scheduledAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Começa em:\n${_countdown(event.scheduledAt)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.groups, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${event.participantCount} participantes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (isLive) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${event.survivorCount} sobreviventes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!isEnded) ...[
                      const SizedBox(height: 10),
                      Text(
                        '🏆 +${event.rewards.xp} XP • ${event.rewards.badgeLabel}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _openEvent,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: isLive
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLive ? 'ENTRAR AGORA' : 'PARTICIPAR',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        'Evento encerrado',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
