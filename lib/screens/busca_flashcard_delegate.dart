import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/content_query_limits.dart';

import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';

import 'tela_flashcards.dart';

class BuscaFlashcardDelegate extends SearchDelegate<String> {
  final String userId;

  BuscaFlashcardDelegate({required this.userId});

  @override
  String get searchFieldLabel => 'Pesquisar matéria ou subtema';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
          icon: const Icon(Icons.clear),
          tooltip: 'Limpar',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Voltar',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildListaResultados(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildListaResultados(context);
  }

  Widget _buildListaResultados(BuildContext context) {
    final termo = ContentHierarchyUtils.normalizeForSearch(query);

    if (termo.isEmpty || termo.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Digite pelo menos 2 letras para pesquisar.\nExemplo: tra, pne, abd',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flashcards')
          .where('searchTerms', arrayContains: termo)
          .limit(ContentQueryLimits.maxSearchResults)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Erro na pesquisa: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhum resultado encontrado.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final resultadosUnicos = <String, Map<String, String>>{};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          final materia = (data['materia'] ?? '').toString().trim();
          final subtema = (data['subtema'] ?? '').toString().trim();
          if (materia.isEmpty || subtema.isEmpty) continue;

          final chave = ContentHierarchyUtils.subtemaPairKey(materia, subtema);

          resultadosUnicos[chave] = {
            'materia': materia,
            'subtema': subtema,
          };
        }

        final resultados = resultadosUnicos.values.toList();

        resultados.sort((a, b) {
          return ContentHierarchyUtils.normalizeForSearch(a['subtema'] ?? '')
              .compareTo(
                  ContentHierarchyUtils.normalizeForSearch(b['subtema'] ?? ''));
        });

        return ListView.separated(
          itemCount: resultados.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = resultados[index];
            final materia = item['materia'] ?? '';
            final subtema = item['subtema'] ?? '';

            return ListTile(
              leading: const Icon(
                Icons.search,
                color: Color(0xFF1E3A8A),
              ),
              title: Text(subtema),
              subtitle: Text(materia),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                close(context, subtema);

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TelaFlashcards(
                      userId: userId,
                      materia: materia,
                      subtema: subtema,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
