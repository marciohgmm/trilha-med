import 'package:flutter/material.dart';

import '../../models/performance_models.dart';
import '../../services/osce/osce_performance_service.dart';
import '../osce/osce_lobby_page.dart';

class PerformanceDetailPage extends StatelessWidget {
  final String userId;
  final String specialtyKey;

  const PerformanceDetailPage({
    super.key,
    required this.userId,
    required this.specialtyKey,
  });

  @override
  Widget build(BuildContext context) {
    final service = OscePerformanceService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(SpecialtyPerformance.specialties[specialtyKey] ?? 'Desempenho'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, SpecialtyPerformance>>(
        stream: service.streamPerformance(userId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sp = snap.data![specialtyKey];
          if (sp == null) {
            return const Center(child: Text('Dados não encontrados.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '${sp.overallPercent}%',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          sp.hasData
                              ? 'Média de ${sp.stationCount} estação${sp.stationCount == 1 ? '' : 'ões'} OSCE'
                              : 'Nenhuma estação avaliada nesta especialidade',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Competências',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 12),
                ...SpecialtyPerformance.skillKeys.map((skill) {
                  final pct = sp.skills[skill] ?? 0;
                  if (!sp.hasData) {
                    return _SkillBar(
                      label: SpecialtyPerformance.skillLabel(skill),
                      percent: 0,
                      muted: true,
                    );
                  }
                  return _SkillBar(
                    label: SpecialtyPerformance.skillLabel(skill),
                    percent: pct,
                  );
                }),
                const SizedBox(height: 20),
                if (sp.hasData && sp.weakestSkill != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ponto mais fraco',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(sp.weakestSkill!),
                        const SizedBox(height: 8),
                        Text(
                          'Sugestão: treine estações OSCE focadas em ${sp.weakestSkill!.toLowerCase()}.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OsceLobbyPage(userId: userId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Treinar agora'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String label;
  final int percent;
  final bool muted;

  const _SkillBar({
    required this.label,
    required this.percent,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$percent%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: muted ? 0 : percent / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: muted ? Colors.grey.shade400 : const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
