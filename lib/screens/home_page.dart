import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/admin_page.dart';
import '../screens/login_page.dart';
import 'temas_page.dart';
import 'cronograma_page.dart';
import 'busca_flashcard_delegate.dart';

class HomePage extends StatefulWidget {
  final String userId;

  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _adminPressTimer;

  Future<void> fazerLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Map<String, int> _agruparMaterias(List<QueryDocumentSnapshot> docs) {
    final Map<String, int> mapa = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final materia = (data['materia'] ?? '').toString().trim();
      if (materia.isNotEmpty) {
        mapa[materia] = (mapa[materia] ?? 0) + 1;
      }
    }

    return mapa;
  }

  void _iniciarPressaoAdmin(Map<String, dynamic> dadosUsuario) {
    _cancelarPressaoAdmin();

    _adminPressTimer = Timer(const Duration(seconds: 4), () {
      final isAdmin = dadosUsuario['isAdmin'] == true;
      if (!mounted) return;

      if (!isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso administrativo restrito.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPage()),
      );
    });
  }

  void _cancelarPressaoAdmin() {
    _adminPressTimer?.cancel();
    _adminPressTimer = null;
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

        final Map<String, dynamic> progressoUsuario =
            dadosUsuario['progresso'] ?? {};
        final bool isAdmin = dadosUsuario['isAdmin'] == true;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          appBar: AppBar(
            title: GestureDetector(
              onTapDown: (_) => _iniciarPressaoAdmin(dadosUsuario),
              onTapUp: (_) => _cancelarPressaoAdmin(),
              onTapCancel: () => _cancelarPressaoAdmin(),
              child: Column(
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
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CronogramaPage(
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              },
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
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('flashcards')
                        .snapshots(),
                    builder: (context, flashSnapshot) {
                      if (!flashSnapshot.hasData) {
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

                      final docs = flashSnapshot.data!.docs;
                      final materiasMap = _agruparMaterias(docs);
                      final materias = materiasMap.keys.toList()..sort();

                      if (materias.isEmpty) {
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

                      return Column(
                        children: materias.map((materia) {
                          final total = materiasMap[materia] ?? 0;

                          final cardsDaMateria = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['materia'] == materia;
                          }).toList();

                          final totalCards = cardsDaMateria.length;

                          final estudados = cardsDaMateria.where((doc) {
                            return progressoUsuario.containsKey(doc.id);
                          }).length;

                          final progresso = totalCards > 0
                              ? estudados / totalCards
                              : 0.0;

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
                                    builder: (_) => TemasPage(
                                      userId: widget.userId,
                                      materia: materia,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A8A)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.menu_book,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      title: Text(
                                        materia,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text('$total flashcards'),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                      ),
                                    ),
                                    LinearProgressIndicator(
                                      value: progresso,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      color: const Color(0xFF1E3A8A),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${(progresso * 100).toStringAsFixed(0)}% concluído • $estudados/$totalCards cards',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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