import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'temas_page.dart';
import '../services/study_timer_service.dart';
import '../widgets/study_timer_overlay.dart';
import 'estatisticas_questoes_page.dart';

class QuestoesPorTemaPage extends StatefulWidget {
  final String userId;
  final String? materia;
  final String? tema;

  const QuestoesPorTemaPage({
    super.key,
    required this.userId,
    this.materia,
    this.tema,
  });

  @override
  State<QuestoesPorTemaPage> createState() => _QuestoesPorTemaPageState();
}

class _QuestoesPorTemaPageState extends State<QuestoesPorTemaPage> {
  final StudyTimerService _timerService = StudyTimerService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _timerService.loadSettings().then((_) {
      _timerService.iniciarEstudo();
    });
    _timerService.alertStream.listen((alert) {
      if (alert == 'pause_reminder') {
        _mostrarAlertaPausa();
      } else if (alert == 'pause_end') {
        _mostrarFimPausa();
      }
    });
  }

  @override
  void dispose() {
    _timerService.pausarEstudo();
    super.dispose();
  }

  void _mostrarAlertaPausa() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('⏱️ Você estudou por 50 minutos. Faça uma pausa de 10 minutos.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Pausar agora',
          onPressed: () {
            _timerService.pausarEstudo();
            _timerService.iniciarPausa();
            _mostrarCronometroPausa();
          },
        ),
      ),
    );
  }

  void _mostrarCronometroPausa() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<Duration>(
        stream: _timerService.pauseTimeStream,
        builder: (context, snapshot) {
          final remaining = snapshot.data ?? _timerService.pauseTime;
          final minutes = remaining.inMinutes;
          final seconds = remaining.inSeconds % 60;

          return AlertDialog(
            title: const Text('Pausa em andamento'),
            content: Text(
              'Tempo restante: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 24),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _timerService.cancelarPausa();
                  Navigator.of(context).pop();
                  _timerService.iniciarEstudo();
                },
                child: const Text('Voltar a estudar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarFimPausa() {
    Navigator.of(context).pop(); // Fechar dialog de pausa
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏱️ Pausa finalizada. Hora de voltar aos estudos!'),
        action: SnackBarAction(
          label: 'Voltar a estudar',
          onPressed: () {
            _timerService.iniciarEstudo();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Questões por Tema'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Estatísticas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EstatisticasQuestoesPage(userId: widget.userId),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Questões por tema',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escolha uma matéria para iniciar as questões.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por matéria...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('questoes')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Erro ao carregar questões: ${snapshot.error}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final docs = snapshot.data!.docs;
                              final materias = <String, int>{};

                              for (final doc in docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final materia = (data['materia'] ?? '').toString().trim();
                                if (materia.isNotEmpty) {
                                  materias[materia] = (materias[materia] ?? 0) + 1;
                                }
                              }

                              final filteredMaterias = materias.keys
                                  .where((materia) => materia.toLowerCase().contains(_searchQuery))
                                  .toList()
                                ..sort();

                              if (filteredMaterias.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Nenhuma matéria encontrada.',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: filteredMaterias.length,
                                itemBuilder: (context, index) {
                                  final materia = filteredMaterias[index];
                                  final count = materias[materia] ?? 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0x1A1E3A8A), // 0xFF1E3A8A with 10% alpha
                                          borderRadius: BorderRadius.all(Radius.circular(8)),
                                        ),
                                        child: const Icon(
                                          Icons.school,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      title: Text(
                                        materia,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text('$count questões'),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TemasPage(
                                              userId: widget.userId,
                                              materia: materia,
                                              collectionName: 'questoes',
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const StudyTimerOverlay(),
          ],
        ),
      ),
    );
  }
}