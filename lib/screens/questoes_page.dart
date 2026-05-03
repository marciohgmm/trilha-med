import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class QuestoesPage extends StatefulWidget {
  final String userId;
  final String? materia;
  final String tema;
  final String subtema;

  const QuestoesPage({
    super.key,
    required this.userId,
    this.materia,
    required this.tema,
    required this.subtema,
  });

  @override
  State<QuestoesPage> createState() => _QuestoesPageState();
}

class _QuestoesPageState extends State<QuestoesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          widget.materia != null ? '${widget.subtema} - ${widget.tema}' : '${widget.subtema} - ${widget.tema}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: () {
          var query = FirebaseFirestore.instance.collection('questoes').where('tema', isEqualTo: widget.tema).where('subtema', isEqualTo: widget.subtema);
          if (widget.materia != null) {
            query = query.where('materia', isEqualTo: widget.materia);
          }
          return query.snapshots();
        }(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma questão encontrada para este subtema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
              final enunciado = data['enunciado'] ?? '';
              final alternativas = List<Map<String, dynamic>>.from(data['alternativas'] ?? []);
              final comentario = data['comentario'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enunciado,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...alternativas.map((alt) {
                        final letra = alt['letra'] ?? '';
                        final texto = alt['texto'] ?? '';
                        final correta = alt['correta'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: correta ? Colors.green.shade50 : Colors.white,
                            border: Border.all(
                              color: correta ? Colors.green : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$letra)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: correta ? Colors.green : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  texto,
                                  style: TextStyle(
                                    color: correta ? Colors.green : Colors.black,
                                  ),
                                ),
                              ),
                              if (correta)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        );
                      }),
                      if (comentario.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Comentário:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comentario,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
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