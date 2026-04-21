import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/criar_flashcard_page.dart';
import 'package:flutter_application_1/services/firebase_service.dart';

class GerenciarFlashcardsPage extends StatefulWidget {
  const GerenciarFlashcardsPage({super.key});

  @override
  State<GerenciarFlashcardsPage> createState() =>
      _GerenciarFlashcardsPageState();
}

class _GerenciarFlashcardsPageState extends State<GerenciarFlashcardsPage> {
  final FirebaseService firebaseService = FirebaseService();

  final Set<String> selecionados = {};
  bool modoSelecao = false;
  bool excluindoLote = false;

  void _entrarModoSelecao(String id) {
    setState(() {
      modoSelecao = true;
      selecionados.add(id);
    });
  }

  void _toggleSelecao(String id) {
    setState(() {
      if (selecionados.contains(id)) {
        selecionados.remove(id);
      } else {
        selecionados.add(id);
      }

      if (selecionados.isEmpty) {
        modoSelecao = false;
      }
    });
  }

  void _cancelarSelecao() {
    setState(() {
      modoSelecao = false;
      selecionados.clear();
    });
  }

  Future<void> _confirmarExclusaoEmLote() async {
    if (selecionados.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir flashcards'),
        content: Text(
          'Deseja excluir ${selecionados.length} flashcard(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      excluindoLote = true;
    });

    try {
      await firebaseService.excluirCardsEmLote(selecionados.toList());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selecionados.length} flashcard(s) excluído(s) com sucesso!',
          ),
        ),
      );

      setState(() {
        selecionados.clear();
        modoSelecao = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir em lote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          excluindoLote = false;
        });
      }
    }
  }

  Future<void> _abrirEdicao({
    required String cardId,
    required Map<String, dynamic> dados,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CriarFlashcardPage(
          cardId: cardId,
          dados: dados,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String cardId,
    required Map<String, dynamic> data,
  }) {
    final materia = (data['materia'] ?? '').toString();
    final tema = (data['tema'] ?? '').toString();
    final subtema = (data['subtema'] ?? '').toString();
    final pergunta = (data['pergunta'] ?? '').toString();
    final resposta = (data['resposta'] ?? '').toString();

    final estaSelecionado = selecionados.contains(cardId);

    return Card(
      elevation: estaSelecionado ? 6 : 3,
      color: estaSelecionado ? const Color(0xFFE8EEFF) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: estaSelecionado
              ? const Color(0xFF1E3A8A)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          if (!modoSelecao) {
            _entrarModoSelecao(cardId);
          }
        },
        onTap: () {
          if (modoSelecao) {
            _toggleSelecao(cardId);
          } else {
            _abrirEdicao(cardId: cardId, dados: data);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (modoSelecao)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        estaSelecionado
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      materia.isEmpty ? 'Sem matéria' : materia,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  if (!modoSelecao)
                    ElevatedButton.icon(
                      onPressed: () => _abrirEdicao(
                        cardId: cardId,
                        dados: data,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tema: ${tema.isEmpty ? "-" : tema}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Subtema: ${subtema.isEmpty ? "-" : subtema}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Pergunta:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pergunta.isEmpty ? '-' : pergunta,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                'Resposta:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resposta.isEmpty ? '-' : resposta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Text(
          modoSelecao
              ? '${selecionados.length} selecionado(s)'
              : 'Gerenciar Flashcards',
        ),
        leading: modoSelecao
            ? IconButton(
                onPressed: _cancelarSelecao,
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (modoSelecao)
            IconButton(
              onPressed: excluindoLote ? null : _confirmarExclusaoEmLote,
              icon: excluindoLote
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.listarCardsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar flashcards: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum flashcard cadastrado ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildCard(
                cardId: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}