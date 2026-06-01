import 'package:flutter/material.dart';

import '../../models/simulado_models.dart';
import '../../services/simulado_service.dart';

class SimuladoHistoricoPage extends StatelessWidget {
  final String userId;

  const SimuladoHistoricoPage({super.key, required this.userId});

  String _formatarTempo(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = SimuladoService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Histórico de simulados'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SimuladoHistorico>>(
        stream: service.streamHistorico(userId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar histórico: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum simulado finalizado ainda.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final h = lista[i];
              final data = h.criadoEm.toLocal();
              final dataStr =
                  '${data.day.toString().padLeft(2, '0')}/'
                  '${data.month.toString().padLeft(2, '0')}/'
                  '${data.year}';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${h.totalQuestoes} questões · '
                    '${h.percentualAcertos.toStringAsFixed(0)}% acertos',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$dataStr · ${_formatarTempo(h.tempoSegundos)}\n'
                    '${h.acertos} acertos · ${h.erros} erros'
                    '${h.naoRespondidas > 0 ? ' · ${h.naoRespondidas} em branco' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${h.filtros.quantidade}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
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
