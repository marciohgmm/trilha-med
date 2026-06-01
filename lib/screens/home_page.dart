import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/application/admin/admin_access_service.dart';
import 'package:flutter_application_1/services/auth/admin_auth_service.dart';
import 'package:flutter_application_1/widgets/admin/admin_gate.dart';
import 'package:flutter_application_1/core/feature_flags/feature_modules.dart';
import 'package:flutter_application_1/widgets/feature_flags/feature_gate.dart';
import 'admin_page.dart';
import 'login_page.dart';
import 'cronograma_page.dart';
import 'questoes_por_tema_page.dart';
import 'subtemas_page.dart';
import 'busca_flashcard_delegate.dart';
import 'package:flutter_application_1/models/flashcard_materia_stat.dart';
import 'package:flutter_application_1/services/flashcard_materia_stats_service.dart';
import 'package:flutter_application_1/widgets/events/events_section.dart';
import 'osce/osce_lobby_page.dart';
import 'medical_tools/medical_tools_page.dart';
import 'revalida_official/revalida_official_landing_page.dart';

class HomePage extends StatefulWidget {
  final String userId;

  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _adminPressTimer;
  final _adminAccess = AdminAccessService.instance;
  final _adminAuth = AdminAuthService();

  Future<void> _fazerLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _abrirFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeDashboardPage(userId: widget.userId),
      ),
    );
  }

  void _abrirQuestoes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestoesPorTemaPage(userId: widget.userId),
      ),
    );
  }

  void _abrirFasePratica() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OsceLobbyPage(userId: widget.userId),
      ),
    );
  }

  void _abrirFerramentasMedicas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MedicalToolsPage(),
      ),
    );
  }

  void _abrirRevalidaOficial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevalidaOfficialLandingPage(userId: widget.userId),
      ),
    );
  }

  void _iniciarPressaoAdmin() {
    _cancelarPressaoAdmin();
    final user = FirebaseAuth.instance.currentUser;
    _adminAuth.logState('botao_oculto_press_inicio', user: user);

    _adminPressTimer = Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;

      _adminAuth.logState('botao_oculto_timer_4s', user: user);
      final result = await _adminAccess.resolveAdminAccess(user: user);

      if (!mounted) return;

      debugPrint(
        '[AdminAuth][botao_oculto] '
        'email=${result.email} uid=${result.uid} '
        'isFounder=${result.isFounder} isAdmin=${result.isAdmin} '
        'listed=${result.listedInAdmins}',
      );

      if (!result.allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Acesso restrito.\n'
              'email=${result.email}\n'
              'founder=${result.isFounder} listed=${result.listedInAdmins}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      debugPrint('[AdminAuth] Abrindo AdminPage (botão oculto)');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPage()),
      );
    });
  }

  Future<void> _abrirAdminTeste() async {
    final user = FirebaseAuth.instance.currentUser;
    final result = await _adminAccess.resolveAdminAccess(user: user);

    debugPrint(
      '[AdminAuth][ABRIR_ADMIN_TESTE] '
      'email=${result.email} uid=${result.uid} '
      'isFounder=${result.isFounder} isAdmin=${result.isAdmin}',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'email: ${result.email}\n'
          'uid: ${result.uid}\n'
          'isFounder: ${result.isFounder}\n'
          'isAdmin: ${result.isAdmin}\n'
          'listed: ${result.listedInAdmins}',
        ),
        duration: const Duration(seconds: 6),
      ),
    );

    if (result.allowed) {
      debugPrint('[AdminAuth] Abrindo AdminPage (teste)');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPage()),
      );
    }
  }

  void _cancelarPressaoAdmin() {
    _adminPressTimer?.cancel();
    _adminPressTimer = null;
  }

  String _authEmailLabel() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return 'Aluno(a)';
    return email.split('@').first;
  }

  @override
  void dispose() {
    _cancelarPressaoAdmin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        Map<String, dynamic> dadosUsuario = {};

        if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
          dadosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
        }

        final nome = (dadosUsuario['nome'] ?? '').toString().trim();
        final displayName =
            nome.isNotEmpty ? nome : _authEmailLabel();
        final email = FirebaseAuth.instance.currentUser?.email;

        return StreamBuilder<bool>(
          stream: _adminAuth.watchIsAdmin(widget.userId, email: email),
          builder: (context, adminSnap) {
            return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          appBar: AppBar(
            title: TrilhaMedAdminTitle(
              onAdminPressStart: _iniciarPressaoAdmin,
              onAdminPressEnd: _cancelarPressaoAdmin,
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: _fazerLogout,
                icon: const Icon(Icons.logout),
                tooltip: 'Sair',
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Escolha como deseja estudar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FeatureGate(
                    moduleId: FeatureModules.revalidaOfficialSimulator,
                    onEnabled: _abrirRevalidaOficial,
                    childBuilder: (onPressed) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x400D9488),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onPressed,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Simulado Revalida Oficial',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '100 questões · 4h · modo prova',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FeatureGate(
                    moduleId: FeatureModules.flashcards,
                    onEnabled: _abrirFlashcards,
                    childBuilder: (onPressed) => ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.style, size: 26),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Estudar por Flashcards',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FeatureGate(
                    moduleId: FeatureModules.questoes,
                    onEnabled: _abrirQuestoes,
                    childBuilder: (onPressed) => ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.quiz, size: 26),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Estudar por Questões',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FeatureGate(
                    moduleId: FeatureModules.fasePratica,
                    onEnabled: _abrirFasePratica,
                    childBuilder: (onPressed) => ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.medical_services, size: 26),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Fase Prática',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FeatureGate(
                    moduleId: FeatureModules.ferramentasMedicas,
                    onEnabled: _abrirFerramentasMedicas,
                    childBuilder: (onPressed) => OutlinedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.medical_information_outlined,
                          size: 22),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Text(
                          'Ferramentas Médicas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(
                            color: Color(0xFF1E3A8A), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FeatureGateSection(
                    moduleId: FeatureModules.liveEvents,
                    child: EventsSection(
                      userId: widget.userId,
                      displayName: displayName,
                    ),
                  ),
                  // TEMP: debug admin — remover após validar acesso
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _abrirAdminTeste,
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('ABRIR ADMIN TESTE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
  }
}

class HomeDashboardPage extends StatefulWidget {
  final String userId;

  const HomeDashboardPage({super.key, required this.userId});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _materiaStats = FlashcardMateriaStatsService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _materiaStats.ensureSeededIfEmpty();
    });
  }

  Future<void> fazerLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        Map<String, dynamic> dadosUsuario = {};

        if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
          dadosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
        }

        final bool isAdmin = dadosUsuario['isAdmin'] == true;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Preparação Revalida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isAdmin)
                  const Text(
                    'Bom estudo!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: BuscaFlashcardDelegate(userId: widget.userId),
                  );
                },
                icon: const Icon(Icons.search),
                tooltip: 'Pesquisar',
              ),
              IconButton(
                onPressed: fazerLogout,
                icon: const Icon(Icons.logout),
                tooltip: 'Sair',
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.local_fire_department, color: Colors.white),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estudo de hoje',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Acesse o cronograma para ver o que estudar hoje, amanhã e nos próximos dias.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          FeatureGate(
                            moduleId: FeatureModules.cronograma,
                            onEnabled: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CronogramaPage(
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            childBuilder: (onPressed) => SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: onPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Ver cronograma',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Matérias',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .collection('progresso')
                        .snapshots(),
                    builder: (context, progressoSnapshot) {
                      return StreamBuilder<List<FlashcardMateriaStat>>(
                        stream: _materiaStats.watchMateriaStats(),
                        builder: (context, statsSnapshot) {
                          if (!statsSnapshot.hasData ||
                              progressoSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text('Carregando matérias...'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final stats = statsSnapshot.data!;
                          if (stats.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Nenhuma matéria encontrada no Firestore.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final progressoDocs = progressoSnapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                          return FutureBuilder<Map<String, int>>(
                            future: _materiaStats.computeEstudadosPorMateria(
                              progressoDocs,
                            ),
                            builder: (context, estudadosSnapshot) {
                              if (!estudadosSnapshot.hasData) {
                                return const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }

                              final rows = _materiaStats.buildHomeRows(
                                stats: stats,
                                estudadosPorMateria: estudadosSnapshot.data!,
                              );

                              return Column(
                                children: rows.map((row) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubtemasPage(
                                              userId: widget.userId,
                                              materia: row.materia,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E3A8A)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.menu_book,
                                                  color: Color(0xFF1E3A8A),
                                                ),
                                              ),
                                              title: Text(
                                                row.materia,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${row.total} flashcards',
                                              ),
                                              trailing: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                              ),
                                            ),
                                            LinearProgressIndicator(
                                              value: row.progresso,
                                              minHeight: 8,
                                              backgroundColor: Colors.grey[300],
                                              color: const Color(0xFF1E3A8A),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${(row.progresso * 100).toStringAsFixed(0)}% concluído • ${row.estudados}/${row.total} cards',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
