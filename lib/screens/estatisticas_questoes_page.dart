import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/questao_service.dart';

class EstatisticasQuestoesPage extends StatelessWidget {
  final String userId;

  const EstatisticasQuestoesPage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Estatísticas (questões)'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: QuestaoService().progressoQuestoesStream(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sem estatísticas ainda.\nResponda algumas questões para aparecer aqui.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final porMateria = <String, ({int total, int erros, Map<String, ({int total, int erros})> porTema})>{};

          for (final d in docs) {
            final data = d.data();
            final materia = (data['materia'] ?? '').toString().trim();
            final tema = (data['tema'] ?? '').toString().trim();
            final acertou = data['acertou'] == true;
            if (materia.isEmpty) continue;

            porMateria.putIfAbsent(
              materia,
              () => (total: 0, erros: 0, porTema: <String, ({int total, int erros})>{}),
            );

            final current = porMateria[materia]!;
            final total = current.total + 1;
            final erros = current.erros + (acertou ? 0 : 1);

            final temaKey = tema.isEmpty ? '(sem tema)' : tema;
            final temaStats = current.porTema[temaKey] ?? (total: 0, erros: 0);
            current.porTema[temaKey] = (
              total: temaStats.total + 1,
              erros: temaStats.erros + (acertou ? 0 : 1),
            );

            porMateria[materia] = (total: total, erros: erros, porTema: current.porTema);
          }

          final materias = porMateria.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materias.length,
            itemBuilder: (context, index) {
              final materia = materias[index];
              final stats = porMateria[materia]!;
              final taxaErro = stats.total == 0 ? 0.0 : stats.erros / stats.total;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bar_chart, color: Color(0xFF1E3A8A)),
                  ),
                  title: Text(
                    materia,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${stats.total} respondidas • ${stats.erros} erradas • ${(100 * taxaErro).toStringAsFixed(0)}% erro',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _EstatisticaMateriaDetalhePage(
                          materia: materia,
                          porTema: stats.porTema,
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

class _EstatisticaMateriaDetalhePage extends StatelessWidget {
  final String materia;
  final Map<String, ({int total, int erros})> porTema;

  const _EstatisticaMateriaDetalhePage({
    required this.materia,
    required this.porTema,
  });

  @override
  Widget build(BuildContext context) {
    final temas = porTema.keys.toList()
      ..sort((a, b) {
        final sa = porTema[a]!;
        final sb = porTema[b]!;
        final ea = sa.total == 0 ? 0.0 : sa.erros / sa.total;
        final eb = sb.total == 0 ? 0.0 : sb.erros / sb.total;
        return eb.compareTo(ea); // mais difícil primeiro
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Estatísticas - $materia'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: temas.length,
        itemBuilder: (context, index) {
          final tema = temas[index];
          final s = porTema[tema]!;
          final taxaErro = s.total == 0 ? 0.0 : s.erros / s.total;
          final cor = taxaErro >= 0.5 ? Colors.red : (taxaErro >= 0.25 ? Colors.orange : Colors.green);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              title: Text(tema, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.total} respondidas • ${(100 * taxaErro).toStringAsFixed(0)}% erro'),
              trailing: Icon(Icons.circle, color: cor, size: 14),
            ),
          );
        },
      ),
    );
  }
}

