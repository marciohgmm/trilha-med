import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'subtemas_page.dart';

class BuscaFlashcardDelegate extends SearchDelegate<String> {
  final String userId;

  BuscaFlashcardDelegate({required this.userId});

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  @override
  String get searchFieldLabel => 'Pesquisar assunto, tema ou subtema';

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
    final termo = _normalizar(query);

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
          .limit(30)
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
          final tema = (data['tema'] ?? '').toString().trim();
          final subtema = (data['subtema'] ?? '').toString().trim();

          final chave = '$materia|$tema|$subtema';

          resultadosUnicos[chave] = {
            'materia': materia,
            'tema': tema,
            'subtema': subtema,
          };
        }

        final resultados = resultadosUnicos.values.toList();

        resultados.sort((a, b) {
          final tituloA =
              (a['subtema']?.isNotEmpty ?? false) ? a['subtema']! : a['tema']!;
          final tituloB =
              (b['subtema']?.isNotEmpty ?? false) ? b['subtema']! : b['tema']!;
          return tituloA.toLowerCase().compareTo(tituloB.toLowerCase());
        });

        return ListView.separated(
          itemCount: resultados.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = resultados[index];
            final materia = item['materia'] ?? '';
            final tema = item['tema'] ?? '';
            final subtema = item['subtema'] ?? '';

            return ListTile(
              leading: const Icon(
                Icons.search,
                color: Color(0xFF1E3A8A),
              ),
              title: Text(subtema.isNotEmpty ? subtema : tema),
              subtitle: Text('$materia • $tema'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                close(context, subtema.isNotEmpty ? subtema : tema);

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubtemasPage(
                      userId: userId,
                      materia: materia,
                      tema: tema,
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