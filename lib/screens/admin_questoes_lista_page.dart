import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/questao_model.dart';
import 'package:flutter_application_1/screens/criar_questao_page.dart';
import 'package:flutter_application_1/services/questao_service.dart';

class AdminQuestoesListaPage extends StatefulWidget {
  final String materia;
  final String tema;
  final String subtema;

  const AdminQuestoesListaPage({
    super.key,
    required this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<AdminQuestoesListaPage> createState() => _AdminQuestoesListaPageState();
}

class _AdminQuestoesListaPageState extends State<AdminQuestoesListaPage> {
  final QuestaoService _service = QuestaoService();
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

  Future<void> _editarQuestao(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final questao = QuestaoModel.fromMap(doc.id, data);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CriarQuestaoPage(questao: questao),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questão atualizada!')),
      );
    }
  }

  Future<void> _excluirQuestao(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir questão'),
        content: const Text('Deseja realmente excluir esta questão?'),
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
      ),
    );
    if (confirmed != true) return;

    final ok = await _service.excluirQuestao(doc.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao excluir questão.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Questão excluída!')),
    );
  }

  Future<void> _excluirSelecionados() async {
    if (_selecionados.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir questões selecionadas'),
        content: Text(
          'Tem certeza que deseja excluir ${_selecionados.length} questão(ões)?',
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
      ),
    );
    if (confirmed != true) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('questoes')
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
        const SnackBar(content: Text('Questões selecionadas excluídas!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir em lote: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _textoEnunciado(Map<String, dynamic> data) {
    return (data['enunciado'] ?? 'Sem enunciado').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: _modoSelecao
            ? Text('${_selecionados.length} selecionado(s)')
            : Text('Questões - ${widget.subtema}'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CriarQuestaoPage(
                initialMateria: widget.materia,
                initialTema: widget.tema,
                initialSubtema: widget.subtema,
              ),
            ),
          );
          if (!mounted) return;
          if (result == true) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('Questão criada!')),
            );
          }
        },
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova questão'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('questoes')
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
              child: Text('Nenhuma questão encontrada neste subtema.'),
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
                    color:
                        selecionado ? const Color(0xFF1E3A8A) : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                    child: Icon(
                      selecionado ? Icons.check : Icons.quiz_outlined,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  title: Text(
                    _textoEnunciado(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${widget.materia} • ${widget.tema} • ${widget.subtema}'),
                  ),
                  trailing: !_modoSelecao
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'editar') {
                              await _editarQuestao(doc);
                            } else if (value == 'excluir') {
                              await _excluirQuestao(doc);
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
                      await _editarQuestao(doc);
                    }
                  },
                  onLongPress: () => _alternarSelecao(doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

