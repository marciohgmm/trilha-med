import 'package:flutter/material.dart';

import '../../services/osce/osce_evaluation_service.dart';
import 'osce_evaluation_page.dart';

class OsceEvaluationHistoryPage extends StatelessWidget {
  final String userId;

  const OsceEvaluationHistoryPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = OsceEvaluationService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Histórico de avaliações'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: service.streamHistoryForUser(userId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma avaliação finalizada ainda.\n'
                  'Complete uma estação OSCE para ver o histórico.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    r.caseTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${r.stationName} · ${r.specialty}'),
                      Text(
                        '${r.createdAt.day.toString().padLeft(2, '0')}/'
                        '${r.createdAt.month.toString().padLeft(2, '0')}/'
                        '${r.createdAt.year}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nota: ${r.totalScore.toStringAsFixed(1)} / ${r.maxScore.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OsceEvaluationResultPage(
                          evaluationId: r.id,
                          userId: userId,
                        ),
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
