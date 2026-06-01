import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_questoes_subtemas_page.dart';
import 'criar_questao_page.dart';

class AdminQuestoesMateriasPage extends StatefulWidget {
  const AdminQuestoesMateriasPage({super.key});

  @override
  State<AdminQuestoesMateriasPage> createState() =>
      _AdminQuestoesMateriasPageState();
}

class _AdminQuestoesMateriasPageState extends State<AdminQuestoesMateriasPage> {
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

  void _abrirSubtemas(String materia) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestoesSubtemasPage(materia: materia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Gerenciar questões'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CriarQuestaoPage()),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova questão'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('questoes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar matérias: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final materiasMap = _agruparMaterias(docs);
          final materias = materiasMap.keys.toList()..sort();

          if (materias.isEmpty) {
            return const Center(
              child: Text('Nenhuma questão cadastrada ainda.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materias.length,
            itemBuilder: (context, index) {
              final materia = materias[index];
              final total = materiasMap[materia] ?? 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    materia,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text('$total questão(ões)'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                  onTap: () => _abrirSubtemas(materia),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
