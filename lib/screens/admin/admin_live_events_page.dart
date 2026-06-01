import 'package:flutter/material.dart';

import '../../models/live_event_models.dart';
import '../../services/live_event_service.dart';
import 'admin_live_event_dashboard_page.dart';
import 'admin_live_event_form_page.dart';

class AdminLiveEventsPage extends StatelessWidget {
  const AdminLiveEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LiveEventService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Eventos ao vivo'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminLiveEventFormPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.add),
        label: const Text('Novo evento'),
      ),
      body: StreamBuilder<List<LiveEventModel>>(
        stream: service.streamPublishedEvents(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const Center(
              child: Text('Nenhum evento cadastrado.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('${e.type.emoji} ${e.title}'),
                  subtitle: Text(
                    '${e.status.value} • ${e.participantCount} inscritos • '
                    '${e.scheduledAt.day}/${e.scheduledAt.month} '
                    '${e.scheduledAt.hour}:${e.scheduledAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminLiveEventDashboardPage(eventId: e.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
