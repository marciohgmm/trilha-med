import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // opcional, se quiser upload de imagem

class TelaFlashcards extends StatefulWidget {
  final String userId;
  final String materia;
  final String tema;
  final String subtema;

  const TelaFlashcards({
    super.key,
    required this.userId,
    required this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<TelaFlashcards> createState() => _TelaFlashcardsState();
}

class _TelaFlashcardsState extends State<TelaFlashcards> {
  int indiceAtual = 0;
  bool mostrandoResposta = false;
  bool salvando = false;
  bool enviandoReport = false;

  void proximoCard(int total) {
    setState(() {
      if (indiceAtual < total - 1) {
        indiceAtual++;
      } else {
        Navigator.pop(context);
      }
      mostrandoResposta = false;
    });
  }

  Future<void> salvarProgresso(String cardId, String dificuldade, int total) async {
    final progressoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('progresso')
        .doc(cardId);

    final resumoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);

    final agora = DateTime.now();

    // 🔥 BUSCA PROGRESSO ATUAL
    final doc = await progressoRef.get();

    int nivelAtual = 0;
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      nivelAtual = data['nivel'] ?? 0;
    }

    // 🔥 REGRAS DE EVOLUÇÃO
    int novoNivel = nivelAtual;

    // Use max 0 e keep within 0..4
    const maxNivel = 4;

    if (dificuldade == "Errei") {
      novoNivel = 0;
    } else if (dificuldade == "Difícil") {
      novoNivel = (nivelAtual - 1).clamp(0, maxNivel);
    } else if (dificuldade == "Fácil") {
      novoNivel = (nivelAtual + 1).clamp(0, maxNivel);
    }
    // "Moderado" -> mantém nível

    // 🔥 CURVA DE REPETIÇÃO
    List<int> intervalos = [1, 3, 7, 15, 30]; // 1, 3, 7, 15, 30

    int intervalo;

    if (novoNivel >= intervalos.length) {
      intervalo = 30;
    } else {
      intervalo = intervalos[novoNivel];
    }

    final proximaRevisao = agora.add(Duration(days: intervalo));

    // 🔥 SALVA PROGRESSO DETALHADO
    await progressoRef.set({
      'cardId': cardId,
      'userId': widget.userId,
      'materia': widget.materia,
      'tema': widget.tema,
      'subtema': widget.subtema,
      'dificuldade': dificuldade,
      'nivel': novoNivel,
      'intervalo': intervalo,
      'proximaRevisao': Timestamp.fromDate(proximaRevisao),
      'dataEstudo': Timestamp.fromDate(agora),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔥 ATUALIZA RESUMO (opcional manter)
    int acertos = 0;
    int erros = 0;

    if (dificuldade == "Errei" || dificuldade == "Difícil") {
      erros = 1;
    } else {
      acertos = 1;
    }

    await resumoRef.set({
      'ultimoAcesso': FieldValue.serverTimestamp(),
      'ultimaMateria': widget.materia,
      'ultimoTema': widget.tema,
      'ultimoSubtema': widget.subtema,
      'totalRespondidas': FieldValue.increment(1),
      'totalAcertos': FieldValue.increment(acertos),
      'totalErros': FieldValue.increment(erros),
    }, SetOptions(merge: true));
  }

  Future<void> enviarReportErro({
    required String cardId,
    required String pergunta,
    required String resposta,
    required String explicacao,
    required int indiceCard,
    required int totalCards,
    required String mensagem,
  }) async {
    final agora = DateTime.now();

    await FirebaseFirestore.instance.collection('notificacoes_admin').add({
      'tipo': 'erro_card',
      'status': 'novo',
      'mensagem': mensagem,
      'userId': widget.userId,
      'materia': widget.materia,
      'tema': widget.tema,
      'subtema': widget.subtema,
      'flashcardDocId': cardId,
      'indiceCard': indiceCard,
      'totalCardsSubtema': totalCards,
      'pergunta': pergunta,
      'resposta': resposta,
      'explicacao': explicacao,
      'criadoEm': Timestamp.fromDate(agora),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> mostrarDialogReport({
    required String cardId,
    required String pergunta,
    required String resposta,
    required String explicacao,
    required int indiceCard,
    required int totalCards,
  }) async {
    final controller = TextEditingController();

    final mensagem = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar erro'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Descreva o erro encontrado neste card',
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
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (mensagem == null || mensagem.isEmpty) return;

    setState(() {
      enviandoReport = true;
    });

    try {
      await enviarReportErro(
        cardId: cardId,
        pergunta: pergunta,
        resposta: resposta,
        explicacao: explicacao,
        indiceCard: indiceCard,
        totalCards: totalCards,
        mensagem: mensagem,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro reportado com sucesso'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
    } catch (e,
        st) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviandoReport = false;
        });
      }
    }
  }

  Future<void> responderCard(String cardId, String dificuldade, int total) async {
    if (salvando) return;

    setState(() {
      salvando = true;
    });

    try {
      await salvarProgresso(cardId, dificuldade, total);

      // Não mostramos mais o SnackBar
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Progresso salvo com sucesso'),
      //     backgroundColor: Color(0xFF1E3A8A),
      //   ),
      // );

      proximoCard(total);
    } catch (e,
        st) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar progresso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(widget.subtema),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
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
              return const Center(child: Text('Sem flashcards'));
            }

            if (indiceAtual >= docs.length) {
              indiceAtual = 0;
            }

            final data = docs[indiceAtual];
            final cardId = data.id;
            final indiceCard = indiceAtual + 1;

            final perguntaTexto = data['pergunta'] ?? '';
            final respostaTexto = data['resposta'] ?? '';
            final imagemPergunta = data['imagemPergunta'] ?? '';
            final imagemResposta = data['imagemResposta'] ?? '';
            final explicacao = data['explicacao'] ?? '';

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey[50]!],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                                () => mostrandoResposta = !mostrandoResposta),
                            child: Column(
                              children: [
                                Text(
                                  mostrandoResposta ? respostaTexto : perguntaTexto,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    height: 1.5,
                                    color: Colors.black87,
                                    fontWeight: !mostrandoResposta
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (!mostrandoResposta &&
                                    imagemPergunta.toString().isNotEmpty)
                                  Image.network(
                                    imagemPergunta,
                                    height: 150,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Text('Imagem não carregada'),
                                  ),
                                if (mostrandoResposta &&
                                    imagemResposta.toString().isNotEmpty)
                                  Image.network(
                                    imagemResposta,
                                    height: 150,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Text('Imagem não carregada'),
                                  ),
                                if (mostrandoResposta &&
                                    explicacao.toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      '💡 $explicacao',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (mostrandoResposta) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (enviandoReport)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: CircularProgressIndicator(),
                              ),
                            TextButton.icon(
                              onPressed: enviandoReport
                                  ? null
                                  : () => mostrarDialogReport(
                                        cardId: cardId,
                                        pergunta: perguntaTexto,
                                        resposta: respostaTexto,
                                        explicacao: explicacao,
                                        indiceCard: indiceCard,
                                        totalCards: docs.length,
                                      ),
                              icon: const Icon(Icons.report_problem_outlined),
                              label: Text(
                                'Reportar erro no card $indiceCard/${docs.length}',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (mostrandoResposta)
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Como foi essa questão?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (salvando)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: CircularProgressIndicator(),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _BotaoDificuldade(
                              texto: 'Fácil',
                              cor: Colors.green,
                              onPressed: () => responderCard(
                                cardId,
                                'Fácil',
                                docs.length,
                              ),
                            ),
                            _BotaoDificuldade(
                              texto: 'Moderado',
                              cor: Colors.blueGrey,
                              onPressed: () => responderCard(
                                cardId,
                                'Moderado',
                                docs.length,
                              ),
                            ),
                            _BotaoDificuldade(
                              texto: 'Difícil',
                              cor: Colors.orange,
                              onPressed: () => responderCard(
                                cardId,
                                'Difícil',
                                docs.length,
                              ),
                            ),
                            _BotaoDificuldade(
                              texto: 'Errei',
                              cor: Colors.red,
                              onPressed: () => responderCard(
                                cardId,
                                'Errei',
                                docs.length,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => setState(() => mostrandoResposta = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Mostrar Resposta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BotaoDificuldade extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback onPressed;

  const _BotaoDificuldade({
    required this.texto,
    required this.cor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}