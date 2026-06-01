import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/feature_flags/feature_modules.dart';
import '../widgets/feature_flags/feature_gate.dart';
import 'subtemas_page.dart';
import '../models/flashcard_materia_stat.dart';
import '../services/questao_materia_stats_service.dart';
import '../services/study_timer_service.dart';
import '../widgets/study_pause_dialog.dart';
import '../widgets/study_timer_overlay.dart';
import 'estatisticas_questoes_page.dart';
import 'login_page.dart';
import 'simulado/simulado_filtros_page.dart';
import 'simulado/simulado_historico_page.dart';

class QuestoesPorTemaPage extends StatefulWidget {
  final String userId;
  final String? materia;

  const QuestoesPorTemaPage({
    super.key,
    required this.userId,
    this.materia,
  });

  @override
  State<QuestoesPorTemaPage> createState() => _QuestoesPorTemaPageState();
}

class _QuestoesPorTemaPageState extends State<QuestoesPorTemaPage> {
  final StudyTimerService _timerService = StudyTimerService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _fazerLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    QuestaoMateriaStatsService.instance.ensureSeededIfEmpty();
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

  void _iniciarPausaComDialogo() {
    _timerService.pausarEstudo();
    _timerService.iniciarPausa();
    StudyPauseDialog.show(context, _timerService);
  }

  void _mostrarAlertaPausa() {
    final min = _timerService.studyDuration.inMinutes;
    final pauseMin = _timerService.pauseDuration.inMinutes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⏱️ Você estudou $min min. Hora de uma pausa de $pauseMin min.',
        ),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Pausar agora',
          onPressed: _iniciarPausaComDialogo,
        ),
      ),
    );
  }

  void _mostrarFimPausa() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '⏰ Pausa finalizada! O despertador tocou — volte aos estudos.',
        ),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Voltar a estudar',
          onPressed: () => _timerService.retomarEstudoAposPausa(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Questões por Matéria'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Histórico de simulados',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimuladoHistoricoPage(userId: widget.userId),
                ),
              );
            },
            icon: const Icon(Icons.history_edu),
          ),
          IconButton(
            tooltip: 'Estatísticas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EstatisticasQuestoesPage(userId: widget.userId),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            onPressed: _fazerLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
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
                    'Questões por matéria',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escolha uma matéria ou faça um simulado personalizado.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  FeatureGate(
                    moduleId: FeatureModules.simulados,
                    onEnabled: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SimuladoFiltrosPage(
                            userId: widget.userId,
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    childBuilder: (onPressed) => SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onPressed,
                        icon: const Icon(Icons.assignment, size: 24),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Fazer Simulado',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
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
                          child: StreamBuilder<List<FlashcardMateriaStat>>(
                            stream: QuestaoMateriaStatsService.instance
                                .watchMateriaStats(),
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
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final stats = snapshot.data!;
                              final filteredMaterias = stats
                                  .where((s) => s.name
                                      .toLowerCase()
                                      .contains(_searchQuery))
                                  .toList()
                                ..sort((a, b) => a.name.compareTo(b.name));

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
                                  final stat = filteredMaterias[index];
                                  final materia = stat.name;
                                  final count = stat.total;

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
                                          color: Color(
                                              0x1A1E3A8A), // 0xFF1E3A8A with 10% alpha
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(8)),
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
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubtemasPage(
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
