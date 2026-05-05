import 'package:flutter/material.dart';

import '../models/questao_model.dart';
import '../services/questao_service.dart';
import 'criar_questao_page.dart';

class EditarQuestoesPage extends StatefulWidget {
  const EditarQuestoesPage({super.key});

  @override
  State<EditarQuestoesPage> createState() => _EditarQuestoesPageState();
}

class _EditarQuestoesPageState extends State<EditarQuestoesPage> {
  final QuestaoService _service = QuestaoService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loadingDelete = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteQuestao(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir questão'),
          content: const Text('Deseja realmente excluir esta questão?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _loadingDelete = true;
    });

    final success = await _service.excluirQuestao(id);

    if (!mounted) return;
    setState(() {
      _loadingDelete = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir questão.')));
    }
  }

  void _openEditor(QuestaoModel questao) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CriarQuestaoPage(questao: questao)),
    );

    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar questões'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      backgroundColor: const Color(0xFFF0F4F8),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por matéria, tema ou subtema',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<QuestaoModel>>(
                stream: _service.getTodasQuestoes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final questoes = snapshot.data!
                      .where((questao) {
                        final search = '${questao.materia} ${questao.tema} ${questao.subtema} ${questao.enunciado}'.toLowerCase();
                        return search.contains(_searchQuery);
                      })
                      .toList();

                  if (questoes.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma questão encontrada.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: questoes.length,
                    itemBuilder: (context, index) {
                      final questao = questoes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          title: Text(questao.enunciado, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${questao.materia} • ${questao.tema} • ${questao.subtema}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                                onPressed: () => _openEditor(questao),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _loadingDelete ? null : () => _deleteQuestao(questao.id),
                              ),
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CriarQuestaoPage()),
          );
          if (result == true) {
            setState(() {});
          }
        },
        label: const Text('Nova questão'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }
}
