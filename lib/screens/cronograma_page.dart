import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/criar_cronograma_page.dart';
import '../screens/tela_flashcards.dart';
import '../services/cronograma_service.dart';

class CronogramaPage extends StatelessWidget {
  final String userId;

  const CronogramaPage({
    super.key,
    required this.userId,
  });

  DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  int _diasRestantes(DateTime prova) {
    final hoje = _somenteData(DateTime.now());
    final provaSemHora = _somenteData(prova);
    return provaSemHora.difference(hoje).inDays.clamp(1, 9999);
  }

  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/"
        "${data.month.toString().padLeft(2, '0')}/"
        "${data.year}";
  }

  void _irParaSubtema(
    BuildContext context,
    String materia,
    String subtema,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaFlashcards(
          userId: userId,
          materia: materia,
          subtema: subtema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = CronogramaService();
    final hojeRaw = DateTime.now();
    final ehFimDeSemana = hojeRaw.weekday == DateTime.saturday ||
        hojeRaw.weekday == DateTime.sunday;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronograma Inteligente'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: 'Editar cronograma',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CriarCronogramaPage(userId: userId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: service.sincronizarSubtemas(userId),
        builder: (context, syncSnapshot) {
          if (syncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (syncSnapshot.hasError) {
            return Center(
              child:
                  Text('Erro ao sincronizar cronograma: ${syncSnapshot.error}'),
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: service.metaCronograma(userId),
            builder: (context, metaSnapshot) {
              if (metaSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (metaSnapshot.hasError) {
                return Center(
                  child: Text(
                      'Erro ao carregar cronograma: ${metaSnapshot.error}'),
                );
              }

              final rawMeta = metaSnapshot.data?.data();
              final metaData = rawMeta is Map<String, dynamic> ? rawMeta : null;

              final dataProva =
                  metaData != null && metaData['dataProva'] != null
                      ? (metaData['dataProva'] as Timestamp).toDate()
                      : null;

              return StreamBuilder<QuerySnapshot>(
                stream: service.itensDeHoje(userId),
                builder: (context, itensSnapshot) {
                  if (itensSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (itensSnapshot.hasError) {
                    return Center(
                      child: Text(
                          'Erro ao carregar cronograma: ${itensSnapshot.error}'),
                    );
                  }

                  final todosItens = itensSnapshot.data?.docs ?? [];
                  final hoje = _somenteData(DateTime.now());

                  final novos = todosItens.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;

                    final dataEstudoTs = data['dataEstudo'];
                    if (dataEstudoTs is! Timestamp) return false;

                    final dataEstudo = _somenteData(dataEstudoTs.toDate());
                    return dataEstudo == hoje;
                  }).toList();

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('progresso')
                        .snapshots(),
                    builder: (context, progressoSnapshot) {
                      if (progressoSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (progressoSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erro ao carregar revisões: ${progressoSnapshot.error}',
                          ),
                        );
                      }

                      final progressoDocs = progressoSnapshot.data?.docs ?? [];

                      final revisoesHoje = progressoDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        if (data == null) return false;

                        final ts = data['proximaRevisao'];
                        if (ts is! Timestamp) return false;

                        final proximaRevisao = _somenteData(ts.toDate());
                        // Apenas as revisões do dia (não acumula atrasadas nem adianta futuras).
                        return proximaRevisao == hoje;
                      }).toList();

                      final diasRestantes =
                          dataProva != null ? _diasRestantes(dataProva) : 0;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Seu plano hoje',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (dataProva != null) ...[
                                    Text(
                                        '📅 Prova: ${_formatarData(dataProva)}'),
                                    Text('⏳ Faltam: $diasRestantes dias'),
                                  ] else
                                    const Text('⚠️ Defina a data da prova'),
                                  const SizedBox(height: 8),
                                  Text(
                                    '🆕 Conteúdo novo hoje: ${ehFimDeSemana ? 0 : novos.length}',
                                  ),
                                  Text(
                                      '🔥 Revisões hoje: ${revisoesHoje.length}'),
                                  if (ehFimDeSemana) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Sábado e domingo: sem conteúdo novo (apenas revisões).',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '🆕 Conteúdo novo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (ehFimDeSemana)
                            const Text(
                                'Fim de semana: sem conteúdo novo programado.')
                          else if (novos.isEmpty)
                            const Text(
                                'Nenhum conteúdo novo programado para hoje.')
                          else ...[
                            ...novos.map(
                              (doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return _ItemCronograma(
                                  titulo: data['materia'] ?? '',
                                  subtitulo:
                                      '${data['materia'] ?? ''} • ${data['subtema'] ?? ''}',
                                  icone: Icons.new_releases,
                                  onTap: () {
                                    _irParaSubtema(
                                      context,
                                      data['materia'] ?? '',
                                      data['subtema'] ?? '',
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (revisoesHoje.isNotEmpty) ...[
                            const Text(
                              '🔥 Revisões de hoje',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...revisoesHoje.map(
                              (doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return _ItemCronograma(
                                  titulo: data['materia'] ?? '',
                                  subtitulo:
                                      '${data['materia'] ?? ''} • ${data['subtema'] ?? ''}',
                                  icone: Icons.refresh,
                                  onTap: () {
                                    _irParaSubtema(
                                      context,
                                      data['materia'] ?? '',
                                      data['subtema'] ?? '',
                                    );
                                  },
                                );
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            const Text('Nenhuma revisão programada para hoje.'),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ItemCronograma extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final VoidCallback onTap;

  const _ItemCronograma({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          icone,
          color: const Color(0xFF1E3A8A),
        ),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}
