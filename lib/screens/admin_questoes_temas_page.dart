import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_questoes_subtemas_page.dart';

class AdminQuestoesTemasPage extends StatefulWidget {
  final String materia;

  const AdminQuestoesTemasPage({
    super.key,
    required this.materia,
  });

  @override
  State<AdminQuestoesTemasPage> createState() => _AdminQuestoesTemasPageState();
}

class _AdminQuestoesTemasPageState extends State<AdminQuestoesTemasPage> {
  Map<String, int> _agruparTemas(List<QueryDocumentSnapshot> docs) {
    final Map<String, int> mapa = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final tema = (data['tema'] ?? '').toString().trim();
      if (tema.isNotEmpty) {
        mapa[tema] = (mapa[tema] ?? 0) + 1;
      }
    }
    return mapa;
  }

  void _abrirSubtemas(String tema) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestoesSubtemasPage(
          materia: widget.materia,
          tema: tema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Temas - ${widget.materia}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('questoes')
            .where('materia', isEqualTo: widget.materia)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final temasMap = _agruparTemas(docs);
          final temas = temasMap.keys.toList()..sort();

          if (temas.isEmpty) {
            return const Center(
              child: Text('Nenhum tema cadastrado nesta matéria.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: temas.length,
            itemBuilder: (context, index) {
              final tema = temas[index];
              final total = temasMap[tema] ?? 0;

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
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.topic_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    tema,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text('$total questão(ões)'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                  onTap: () => _abrirSubtemas(tema),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

