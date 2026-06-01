import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/live_event_models.dart';
import '../../services/live_event_service.dart';
import 'live_event_play_page.dart';

class LiveEventEliminatedPage extends StatelessWidget {
  final String eventId;
  final String userId;
  final LiveEventParticipant participant;
  final LiveEventModel event;

  const LiveEventEliminatedPage({
    super.key,
    required this.eventId,
    required this.userId,
    required this.participant,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.2),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('💀', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    const Text(
                      'Você foi eliminado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rodada ${participant.eliminatedAtRound != null ? participant.eliminatedAtRound! + 1 : '—'}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _statRow('Acertos', '${participant.correctAnswers}'),
              _statRow('Pontuação', '${participant.score}'),
              _statRow('XP ganho', '${participant.xpEarned}'),
              if (participant.finalRank != null)
                _statRow('Posição final', '#${participant.finalRank}'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await LiveEventService().switchToSpectator(eventId, userId);
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveEventPlayPage(
                          eventId: eventId,
                          userId: userId,
                          displayName: participant.displayName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Assistir restante do evento'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final text =
                      'Fui eliminado no ${event.title} — ${participant.correctAnswers} acertos!';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Texto copiado para compartilhar')),
                  );
                },
                icon: const Icon(Icons.share, color: Colors.white70),
                label: const Text('Compartilhar resultado'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Sair', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
