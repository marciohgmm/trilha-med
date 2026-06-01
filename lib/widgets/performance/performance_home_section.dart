import 'package:flutter/material.dart';

import '../../models/performance_models.dart';
import '../../screens/osce/osce_evaluation_history_page.dart';
import '../../screens/performance/performance_detail_page.dart';
import '../../services/osce/osce_performance_service.dart';

class PerformanceHomeSection extends StatelessWidget {
  final String userId;

  const PerformanceHomeSection({super.key, required this.userId});

  Color _colorForPercent(int p) {
    if (p >= 70) return const Color(0xFF059669);
    if (p >= 50) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String _emojiForPercent(int p) {
    if (p >= 70) return '🟩';
    if (p >= 50) return '🟨';
    return '🟥';
  }

  @override
  Widget build(BuildContext context) {
    final service = OscePerformanceService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Seu Desempenho',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OsceEvaluationHistoryPage(userId: userId),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Histórico'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Média das notas das estações OSCE que você concluiu como médico avaliado',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        StreamBuilder<Map<String, SpecialtyPerformance>>(
          stream: service.streamPerformance(userId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snap.data!;
            final keys = SpecialtyPerformance.specialties.keys.toList();

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cross = w >= 500 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, i) {
                    final key = keys[i];
                    final sp = all[key]!;
                    final color = sp.hasData
                        ? _colorForPercent(sp.overallPercent)
                        : Colors.grey;
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PerformanceDetailPage(
                                userId: userId,
                                specialtyKey: key,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _emojiForPercent(sp.overallPercent),
                                style: const TextStyle(fontSize: 18),
                              ),
                              const Spacer(),
                              Text(
                                sp.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sp.hasData ? '${sp.overallPercent}%' : '—',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              if (sp.hasData)
                                Text(
                                  '${sp.stationCount} estação${sp.stationCount == 1 ? '' : 'ões'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              else
                                Text(
                                  'Sem estações',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
