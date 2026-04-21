import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'tela_flashcards.dart';

class SubtemasPage extends StatelessWidget {
  final String userId;
  final String materia;
  final String tema;

  const SubtemasPage({
    super.key,
    required this.userId,
    required this.materia,
    required this.tema,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          '$tema - $materia',
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
        stream: FirebaseFirestore.instance
            .collection('flashcards')
            .where('materia', isEqualTo: materia)
            .where('tema', isEqualTo: tema)
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
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum subtema encontrado para este tema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subtemas disponíveis',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: subtemas.length,
                    itemBuilder: (context, index) {
                      final subtema = subtemas[index];
                      final total = subtemasMap[subtema] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.quiz,
                              color: Color(0xFF1E3A8A),
                              size: 28,
                            ),
                          ),
                          title: Text(
                            subtema,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('$total flashcards neste subtema'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF1E3A8A),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaFlashcards(
                                  userId: userId,
                                  materia: materia,
                                  tema: tema,
                                  subtema: subtema,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}