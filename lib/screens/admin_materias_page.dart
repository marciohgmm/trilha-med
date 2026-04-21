import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'criar_flashcard_page.dart';
import 'admin_temas_page.dart';

class AdminMateriasPage extends StatefulWidget {
  const AdminMateriasPage({super.key});

  @override
  State<AdminMateriasPage> createState() => _AdminMateriasPageState();
}

class _AdminMateriasPageState extends State<AdminMateriasPage> {
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

  Future<void> _renomearMateria(String materiaAtual) async {
    final controller = TextEditingController(text: materiaAtual);

    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renomear matéria'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Novo nome da matéria',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (novoNome == null || novoNome.isEmpty || novoNome == materiaAtual) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('flashcards')
          .where('materia', isEqualTo: materiaAtual)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.update(doc.reference, {'materia': novoNome});
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Matéria renomeada para "$novoNome"'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao renomear matéria: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirMateria(String materia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir matéria'),
          content: Text(
            'Tem certeza que deseja excluir a matéria "$materia" e todos os flashcards vinculados a ela?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('flashcards')
          .where('materia', isEqualTo: materia)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Matéria "$materia" excluída com sucesso'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir matéria: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirTemas(String materia) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminTemasPage(materia: materia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Gerenciar matérias"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('flashcards')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final materiasMap = _agruparMaterias(docs);
          final materias = materiasMap.keys.toList()..sort();

          if (materias.isEmpty) {
            return const Center(
              child: Text("Nenhum conteúdo cadastrado ainda"),
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
                      color: const Color(0xFF1E3A8A).withOpacity(0.10),
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
                  subtitle: Text('$total flashcards cadastrados'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'renomear') {
                        await _renomearMateria(materia);
                      } else if (value == 'excluir') {
                        await _excluirMateria(materia);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'renomear',
                        child: Text('Renomear'),
                      ),
                      PopupMenuItem(
                        value: 'excluir',
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
                  onTap: () => _abrirTemas(materia),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CriarFlashcardPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo flashcard'),
      ),
    );
  }
}