import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_subtemas_page.dart';

class AdminTemasPage extends StatefulWidget {
  final String materia;

  const AdminTemasPage({
    super.key,
    required this.materia,
  });

  @override
  State<AdminTemasPage> createState() => _AdminTemasPageState();
}

class _AdminTemasPageState extends State<AdminTemasPage> {
  Map<String, int> _agruparTemas(List<QueryDocumentSnapshot> docs) {
    final Map<String, int> mapa = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final tema = (data['tema'] ?? '').toString().trim();

      if (tema.isNotEmpty) {
        mapa[tema] = (mapa[tema] ?? 0) + 1;
      }
    }

    return mapa;
  }

  Future<void> _renomearTema(String temaAtual) async {
    final controller = TextEditingController(text: temaAtual);

    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renomear tema'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Novo nome do tema',
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

    if (novoNome == null || novoNome.isEmpty || novoNome == temaAtual) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('flashcards')
          .where('materia', isEqualTo: widget.materia)
          .where('tema', isEqualTo: temaAtual)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.update(doc.reference, {'tema': novoNome});
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema renomeado para "$novoNome"'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao renomear tema: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirTema(String tema) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir tema'),
          content: Text(
            'Tem certeza que deseja excluir o tema "$tema" e todos os flashcards vinculados a ele?',
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
          .where('materia', isEqualTo: widget.materia)
          .where('tema', isEqualTo: tema)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema "$tema" excluído com sucesso'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir tema: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirSubtemas(String tema) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSubtemasPage(
          materia: widget.materia,
          tema: tema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Temas - ${widget.materia}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('flashcards')
            .where('materia', isEqualTo: widget.materia)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final temasMap = _agruparTemas(docs);
          final temas = temasMap.keys.toList()..sort();

          if (temas.isEmpty) {
            return const Center(
              child: Text("Nenhum tema cadastrado nesta matéria"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: temas.length,
            itemBuilder: (context, index) {
              final tema = temas[index];
              final total = temasMap[tema] ?? 0;

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
                      Icons.topic_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    tema,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text('$total flashcards cadastrados'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'renomear') {
                        await _renomearTema(tema);
                      } else if (value == 'excluir') {
                        await _excluirTema(tema);
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
                  onTap: () => _abrirSubtemas(tema),
                ),
              );
            },
          );
        },
      ),
    );
  }
}