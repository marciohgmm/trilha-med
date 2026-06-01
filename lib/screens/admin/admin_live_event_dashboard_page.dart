import 'package:flutter/material.dart';

import '../../models/live_event_models.dart';
import '../../services/live_event_service.dart';

class AdminLiveEventDashboardPage extends StatelessWidget {
  final String eventId;

  const AdminLiveEventDashboardPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final service = LiveEventService();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        title: const Text('Painel ao vivo'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<LiveEventModel?>(
        stream: service.streamEvent(eventId),
        builder: (context, snap) {
          final event = snap.data;
          if (event == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final round = event.currentRound;
          final q = round.question;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${event.type.emoji} ${event.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Status: ${event.status.value}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _kpi('👥', '${event.participantCount}', 'inscritos'),
                  _kpi('⚡', '${event.survivorCount}', 'vivos'),
                  _kpi('💀', '${event.eliminatedCount}', 'eliminados'),
                ],
              ),
              if (event.isLive && q != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rodada ${round.index + 1} • ${round.phase.value}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.enunciado,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '✅ ${round.correctCount}  ❌ ${round.wrongCount + round.skippedCount}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (event.status == LiveEventStatus.scheduled ||
                  event.status == LiveEventStatus.upcoming)
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await service.startEvent(eventId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Evento iniciado!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar evento agora'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              if (event.isLive) ...[
                FilledButton.icon(
                  onPressed: () => service.advanceToReveal(eventId),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Forçar revelação'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => service.advanceFromReveal(eventId),
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Próxima rodada'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => service.endEvent(eventId),
                  icon: const Icon(Icons.stop, color: Colors.red),
                  label: const Text(
                    'Finalizar evento',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Cancelar evento?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Não'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Sim'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await service.cancelEvent(eventId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Cancelar evento'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ranking (top 10)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              StreamBuilder<List<LiveEventParticipant>>(
                stream: service.streamTopRanking(eventId),
                builder: (context, rankSnap) {
                  final list = rankSnap.data ?? [];
                  return Column(
                    children: list.asMap().entries.map((e) {
                      final p = e.value;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${e.key + 1}'),
                        ),
                        title: Text(
                          p.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${p.correctAnswers} acertos • ${p.status.value}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Text(
                          '${p.score}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(String icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$icon $value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
