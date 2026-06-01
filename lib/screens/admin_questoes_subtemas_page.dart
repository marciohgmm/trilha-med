import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';

import 'admin_questoes_lista_page.dart';

class AdminQuestoesSubtemasPage extends StatefulWidget {
  final String materia;

  const AdminQuestoesSubtemasPage({
    super.key,
    required this.materia,
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
        title: Text('Subtemas — ${widget.materia}'),
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
          final subtemasMap = _agruparSubtemas(docs);
          final subtemas =
              ContentHierarchyUtils.sortAlphabetically(subtemasMap.keys);

          if (subtemas.isEmpty) {
            return const Center(
              child: Text('Nenhum subtema cadastrado nesta matéria.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subtemas.length,
            itemBuilder: (context, index) {
              final subtema = subtemas[index];
              final total = subtemasMap[subtema] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    subtema,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$total questões'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
