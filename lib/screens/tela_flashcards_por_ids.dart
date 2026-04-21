import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaFlashcardsPorIds extends StatefulWidget {
  final List<String> flashcardIds;

  const TelaFlashcardsPorIds({
    super.key,
    required this.flashcardIds,
  });

  @override
  State<TelaFlashcardsPorIds> createState() => _TelaFlashcardsPorIdsState();
}

class _TelaFlashcardsPorIdsState extends State<TelaFlashcardsPorIds> {
  List<Map<String, dynamic>> flashcards = [];
  int indexAtual = 0;
  bool mostrarResposta = false;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    buscarFlashcards();
  }

  Future<void> buscarFlashcards() async {
    if (widget.flashcardIds.isEmpty) {
      setState(() {
        flashcards = [];
        carregando = false;
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('flashcards')
        .where(FieldPath.documentId, whereIn: widget.flashcardIds)
        .get();

    setState(() {
      flashcards = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      carregando = false;
    });
  }

  void proximoCard() {
    if (indexAtual < flashcards.length - 1) {
      setState(() {
        indexAtual++;
        mostrarResposta = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fim dos flashcards')),
      );
    }
  }

  void voltarCard() {
    if (indexAtual > 0) {
      setState(() {
        indexAtual--;
        mostrarResposta = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (flashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Flashcards'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Nenhum flashcard encontrado'),
        ),
      );
    }

    final card = flashcards[indexAtual];
    final pergunta = card['pergunta']?.toString() ?? '';
    final resposta = card['resposta']?.toString() ?? '';
    final explicacao = card['explicacao']?.toString() ?? '';
    final materia = card['materia']?.toString() ?? '';
    final tema = card['tema']?.toString() ?? '';
    final subtema = card['subtema']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcard ${indexAtual + 1}/${flashcards.length}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (materia.isNotEmpty || tema.isNotEmpty || subtema.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  [materia, tema, subtema]
                      .where((item) => item.isNotEmpty)
                      .join(' • '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mostrarResposta ? resposta : pergunta,
                            style: const TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          if (mostrarResposta && explicacao.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Explicação',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              explicacao,
                              style: const TextStyle(fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    mostrarResposta = !mostrarResposta;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  mostrarResposta ? 'Ver pergunta' : 'Ver resposta',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: indexAtual > 0 ? voltarCard : null,
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: proximoCard,
                    child: const Text('Próximo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}