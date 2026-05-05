import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_questoes_lista_page.dart';

class AdminQuestoesSubtemasPage extends StatefulWidget {
  final String materia;
  final String tema;

  const AdminQuestoesSubtemasPage({
    super.key,
    required this.materia,
    required this.tema,
  });

  @override
  State<AdminQuestoesSubtemasPage> createState() =>
      _AdminQuestoesSubtemasPageState();
}

class _AdminQuestoesSubtemasPageState extends State<AdminQuestoesSubtemasPage> {
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

  void _abrirLista(String subtema) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestoesListaPage(
          materia: widget.materia,
          tema: widget.tema,
          subtema: subtema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Subtemas - ${widget.tema}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('questoes')
            .where('materia', isEqualTo: widget.materia)
            .where('tema', isEqualTo: widget.tema)
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
              child: Text('Nenhum subtema cadastrado neste tema.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subtemas.length,
            itemBuilder: (context, index) {
              final subtema = subtemas[index];
              final total = subtemasMap[subtema] ?? 0;

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
                      Icons.account_tree_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    subtema,
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
                  onTap: () => _abrirLista(subtema),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

