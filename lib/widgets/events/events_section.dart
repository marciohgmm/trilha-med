import 'package:flutter/material.dart';

import '../../models/live_event_models.dart';
import '../../services/live_event_service.dart';
import 'live_event_card.dart';

/// Seção horizontal de eventos — preparada para múltiplos tipos no futuro.
class EventsSection extends StatelessWidget {
  final String userId;
  final String displayName;

  const EventsSection({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final service = LiveEventService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Eventos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AO VIVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Competições premium — sobreviva às questões',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 280,
          child: StreamBuilder<List<LiveEventModel>>(
            stream: service.streamPublishedEvents(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _errorCard('${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = snapshot.data ?? [];
              final visible = events
                  .where(
                    (e) =>
                        e.status != LiveEventStatus.cancelled &&
                        e.status != LiveEventStatus.ended,
                  )
                  .toList();

              if (visible.isEmpty) {
                return _placeholderCard(context);
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final event = visible[index];
                  return LiveEventCard(
                    event: event,
                    userId: userId,
                    displayName: displayName,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        'Não foi possível carregar eventos.\n$message',
        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
      ),
    );
  }

  Widget _placeholderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🔥 Último Sobrevivente',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nenhum evento agendado no momento.\nFique atento — em breve uma nova batalha.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
