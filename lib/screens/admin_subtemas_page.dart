import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_cards_page.dart';

class AdminSubtemasPage extends StatefulWidget {
  final String materia;
  final String tema;

  const AdminSubtemasPage({
    super.key,
    required this.materia,
    required this.tema,
  });

  @override
  State<AdminSubtemasPage> createState() => _AdminSubtemasPageState();
}

class _AdminSubtemasPageState extends State<AdminSubtemasPage> {
  Map<String, int> _agruparSubtemas(List<QueryDocumentSnapshot> docs) {
    final Map<String, int> mapa = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final subtema = (data['subtema'] ?? '').toString().trim();

      if (subtema.isNotEmpty) {
        mapa[subtema] = (mapa[subtema] ?? 0) + 1;
      }
    }

    return mapa;
  }

  Future<void> _renomearSubtema(String subtemaAtual) async {
    final controller = TextEditingController(text: subtemaAtual);

    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renomear subtema'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Novo nome do subtema',
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

    if (novoNome == null || novoNome.isEmpty || novoNome == subtemaAtual) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('flashcards')
          .where('materia', isEqualTo: widget.materia)
          .where('tema', isEqualTo: widget.tema)
          .where('subtema', isEqualTo: subtemaAtual)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.update(doc.reference, {'subtema': novoNome});
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtema renomeado para "$novoNome"'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao renomear subtema: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirSubtema(String subtema) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir subtema'),
          content: Text(
            'Tem certeza que deseja excluir o subtema "$subtema" e todos os flashcards vinculados a ele?',
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
          .where('tema', isEqualTo: widget.tema)
          .where('subtema', isEqualTo: subtema)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtema "$subtema" excluído com sucesso'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir subtema: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirCards(String subtema) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCardsPage(
          materia: widget.materia,
          tema: widget.tema,
          subtema: subtema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Subtemas - ${widget.tema}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('flashcards')
            .where('materia', isEqualTo: widget.materia)
            .where('tema', isEqualTo: widget.tema)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final subtemasMap = _agruparSubtemas(docs);
          final subtemas = subtemasMap.keys.toList()..sort();

          if (subtemas.isEmpty) {
            return const Center(
              child: Text("Nenhum subtema cadastrado neste tema"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subtemas.length,
            itemBuilder: (context, index) {
              final subtema = subtemas[index];
              final total = subtemasMap[subtema] ?? 0;

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
                      Icons.account_tree_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    subtema,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text('$total flashcards cadastrados'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'renomear') {
                        await _renomearSubtema(subtema);
                      } else if (value == 'excluir') {
                        await _excluirSubtema(subtema);
                      } else if (value == 'editar_cards') {
                        _abrirCards(subtema);
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
                      PopupMenuItem(
                        value: 'editar_cards',
                        child: Text('Editar cards'),
                      ),
                    ],
                  ),
                  onTap: () => _abrirCards(subtema),
                ),
              );
            },
          );
        },
      ),
    );
  }
}