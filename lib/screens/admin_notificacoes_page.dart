import 'package:flutter_application_1/screens/criar_flashcard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificacoesPage extends StatelessWidget {
  const AdminNotificacoesPage({super.key});

  Color _corStatus(String status) {
    switch (status) {
      case 'novo':
        return Colors.red;
      case 'em_analise':
        return Colors.orange;
      case 'resolvido':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _textoTipo(String tipo) {
    switch (tipo) {
      case 'erro_card':
        return 'Erro em card';
      case 'contato_admin':
        return 'Contato com admin';
      default:
        return tipo;
    }
  }

  Future<void> _atualizarStatus(String docId, String novoStatus) async {
    await FirebaseFirestore.instance
        .collection('notificacoes_admin')
        .doc(docId)
        .update({
      'status': novoStatus,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _excluirNotificacao(String docId) async {
    await FirebaseFirestore.instance
        .collection('notificacoes_admin')
        .doc(docId)
        .delete();
  }

  void _abrirDetalhes(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminNotificacaoDetalhePage(data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Notificações Admin'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notificacoes_admin')
            .orderBy('criadoEm', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma notificação recebida ainda.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final tipo = (data['tipo'] ?? '').toString();
              final status = (data['status'] ?? 'novo').toString();
              final mensagem = (data['mensagem'] ?? '').toString();
              final materia = (data['materia'] ?? '').toString();
              final tema = (data['tema'] ?? '').toString();
              final subtema = (data['subtema'] ?? '').toString();
              final indiceCard = (data['indiceCard'] ?? '').toString();
              final totalCards = (data['totalCardsSubtema'] ?? '').toString();
              final pergunta = (data['pergunta'] ?? '').toString();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _abrirDetalhes(context, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _corStatus(status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _corStatus(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'novo') {
                                  await _atualizarStatus(doc.id, 'novo');
                                } else if (value == 'em_analise') {
                                  await _atualizarStatus(doc.id, 'em_analise');
                                } else if (value == 'resolvido') {
                                  await _atualizarStatus(doc.id, 'resolvido');
                                } else if (value == 'excluir') {
                                  await _excluirNotificacao(doc.id);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'novo',
                                  child: Text('Marcar como novo'),
                                ),
                                PopupMenuItem(
                                  value: 'em_analise',
                                  child: Text('Marcar em análise'),
                                ),
                                PopupMenuItem(
                                  value: 'resolvido',
                                  child: Text('Marcar resolvido'),
                                ),
                                PopupMenuItem(
                                  value: 'excluir',
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _textoTipo(tipo),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (materia.isNotEmpty) Text('Matéria: $materia'),
                        if (tema.isNotEmpty) Text('Tema: $tema'),
                        if (subtema.isNotEmpty) Text('Subtema: $subtema'),
                        if (indiceCard.isNotEmpty && totalCards.isNotEmpty)
                          Text('Card: $indiceCard/$totalCards'),
                        if (pergunta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Pergunta reportada:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pergunta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Mensagem:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mensagem.isEmpty ? 'Sem mensagem informada.' : mensagem,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Toque para ver detalhes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
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
      ),
    );
  }
}

class AdminNotificacaoDetalhePage extends StatelessWidget {
  final Map<String, dynamic> data;

  const AdminNotificacaoDetalhePage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = (data['tipo'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final mensagem = (data['mensagem'] ?? '').toString();
    final materia = (data['materia'] ?? '').toString();
    final tema = (data['tema'] ?? '').toString();
    final subtema = (data['subtema'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();
    final pergunta = (data['pergunta'] ?? '').toString();
    final resposta = (data['resposta'] ?? '').toString();
    final explicacao = (data['explicacao'] ?? '').toString();
    final indiceCard = (data['indiceCard'] ?? '').toString();
    final totalCards = (data['totalCardsSubtema'] ?? '').toString();
    final flashcardDocId = (data['flashcardDocId'] ?? '').toString();

    final podeEditarCard = tipo == 'erro_card' && flashcardDocId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Detalhes da notificação'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SecaoDetalhe(titulo: 'Tipo', conteudo: tipo),
          _SecaoDetalhe(titulo: 'Status', conteudo: status),
          _SecaoDetalhe(titulo: 'Matéria', conteudo: materia),
          _SecaoDetalhe(titulo: 'Tema', conteudo: tema),
          _SecaoDetalhe(titulo: 'Subtema', conteudo: subtema),
          _SecaoDetalhe(titulo: 'Usuário', conteudo: userId),
          _SecaoDetalhe(
            titulo: 'Posição do card',
            conteudo: (indiceCard.isNotEmpty && totalCards.isNotEmpty)
                ? '$indiceCard de $totalCards'
                : '',
          ),
          if (podeEditarCard)
            _SecaoDetalhe(titulo: 'ID do card', conteudo: flashcardDocId),
          _SecaoDetalhe(titulo: 'Pergunta', conteudo: pergunta),
          _SecaoDetalhe(titulo: 'Resposta', conteudo: resposta),
          _SecaoDetalhe(titulo: 'Explicação', conteudo: explicacao),
          _SecaoDetalhe(titulo: 'Mensagem do aluno', conteudo: mensagem),
          const SizedBox(height: 24),
          if (podeEditarCard) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CriarFlashcardPage(
                      cardId: flashcardDocId,
                      dados: {
                        'materia': materia,
                        'tema': tema,
                        'subtema': subtema,
                        'pergunta': pergunta,
                        'resposta': resposta,
                        'explicacao': explicacao,
                      },
                    ),
                  ),
                );

                if (resultado == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Card atualizado com sucesso!'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar este card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecaoDetalhe extends StatelessWidget {
  final String titulo;
  final String conteudo;

  const _SecaoDetalhe({
    required this.titulo,
    required this.conteudo,
  });

  @override
  Widget build(BuildContext context) {
    if (conteudo.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conteudo,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}