import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCardsPage extends StatefulWidget {
  final String materia;
  final String tema;
  final String subtema;

  const AdminCardsPage({
    super.key,
    required this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<AdminCardsPage> createState() => _AdminCardsPageState();
}

class _AdminCardsPageState extends State<AdminCardsPage> {
  final Set<String> _selecionados = {};

  bool get _modoSelecao => _selecionados.isNotEmpty;

  void _alternarSelecao(String docId) {
    setState(() {
      if (_selecionados.contains(docId)) {
        _selecionados.remove(docId);
      } else {
        _selecionados.add(docId);
      }
    });
  }

  void _limparSelecao() {
    setState(() {
      _selecionados.clear();
    });
  }

  Future<void> _editarCard(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final perguntaController = TextEditingController(
      text: (data['pergunta'] ?? data['enunciado'] ?? '').toString(),
    );
    final respostaController = TextEditingController(
      text: (data['resposta'] ?? '').toString(),
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar card'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: perguntaController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Pergunta / Enunciado',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: respostaController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Resposta',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    final novaPergunta = perguntaController.text.trim();
    final novaResposta = respostaController.text.trim();

    if (novaPergunta.isEmpty || novaResposta.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pergunta e resposta não podem ficar vazias.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await doc.reference.update({
        'pergunta': novaPergunta,
        'enunciado': novaPergunta,
        'resposta': novaResposta,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card atualizado com sucesso!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirCard(DocumentSnapshot doc) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir card'),
          content: const Text('Tem certeza que deseja excluir este card?'),
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
      await doc.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card excluído com sucesso!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excluirSelecionados() async {
    if (_selecionados.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cards selecionados'),
          content: Text(
            'Tem certeza que deseja excluir ${_selecionados.length} card(s)?',
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
          .where('subtema', isEqualTo: widget.subtema)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        if (_selecionados.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      if (!mounted) return;

      _limparSelecao();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cards selecionados excluídos com sucesso!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _textoPergunta(Map<String, dynamic> data) {
    return (data['pergunta'] ?? data['enunciado'] ?? 'Sem pergunta')
        .toString();
  }

  String _textoResposta(Map<String, dynamic> data) {
    return (data['resposta'] ?? 'Sem resposta').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: _modoSelecao
            ? Text('${_selecionados.length} selecionado(s)')
            : Text('Cards - ${widget.subtema}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          if (_modoSelecao)
            IconButton(
              onPressed: _excluirSelecionados,
              icon: const Icon(Icons.delete_outline),
            ),
          if (_modoSelecao)
            IconButton(
              onPressed: _limparSelecao,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('flashcards')
            .where('materia', isEqualTo: widget.materia)
            .where('tema', isEqualTo: widget.tema)
            .where('subtema', isEqualTo: widget.subtema)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Nenhum card encontrado neste subtema'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final selecionado = _selecionados.contains(doc.id);

              return Card(
                elevation: selecionado ? 5 : 2,
                color: selecionado ? const Color(0xFFDCE8FF) : Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selecionado
                        ? const Color(0xFF1E3A8A)
                        : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.10),
                    child: Icon(
                      selecionado ? Icons.check : Icons.style_outlined,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  title: Text(
                    _textoPergunta(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _textoResposta(data),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: !_modoSelecao
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'editar') {
                              await _editarCard(doc);
                            } else if (value == 'excluir') {
                              await _excluirCard(doc);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
                        )
                      : null,
                  onTap: () async {
                    if (_modoSelecao) {
                      _alternarSelecao(doc.id);
                    } else {
                      await _editarCard(doc);
                    }
                  },
                  onLongPress: () {
                    _alternarSelecao(doc.id);
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