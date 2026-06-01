import 'package:flutter/material.dart';

import 'package:flutter_application_1/models/flashcard_subtema_catalog_entry.dart';

import 'package:flutter_application_1/models/questao_subtema_catalog_entry.dart';

import 'package:flutter_application_1/services/flashcard_subtema_catalog_service.dart';

import 'package:flutter_application_1/services/questao_subtema_catalog_service.dart';

import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';



import 'questoes_page.dart';

import 'tela_flashcards.dart';



class SubtemasPage extends StatefulWidget {

  final String userId;

  final String materia;

  final String collectionName;



  const SubtemasPage({

    super.key,

    required this.userId,

    required this.materia,

    this.collectionName = 'flashcards',

  });



  @override

  State<SubtemasPage> createState() => _SubtemasPageState();

}



class _SubtemasPageState extends State<SubtemasPage> {

  String _busca = '';



  bool get _isQuestoes => widget.collectionName == 'questoes';

  @override
  void initState() {
    super.initState();
    if (_isQuestoes) {
      QuestaoSubtemaCatalogService.instance.ensureSeededIfEmpty();
    } else {
      FlashcardSubtemaCatalogService.instance.ensureSeededIfEmpty();
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF0F4F8),

      appBar: AppBar(

        title: Text(

          widget.materia,

          style: const TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),

        backgroundColor: const Color(0xFF1E3A8A),

        foregroundColor: Colors.white,

        centerTitle: true,

      ),

      body: StreamBuilder<List<dynamic>>(

        stream: _isQuestoes

            ? QuestaoSubtemaCatalogService.instance

                .watchByMateria(widget.materia)

                .map((list) => list)

            : FlashcardSubtemaCatalogService.instance

                .watchByMateria(widget.materia)

                .map((list) => list),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting &&

              !snapshot.hasData) {

            return const Center(child: CircularProgressIndicator());

          }



          if (snapshot.hasError) {

            return Center(child: Text('Erro: ${snapshot.error}'));

          }



          final entries = snapshot.data ?? [];

          final subtemasMap = <String, int>{};



          for (final entry in entries) {

            if (entry is QuestaoSubtemaCatalogEntry) {

              subtemasMap[entry.subtema] = entry.questaoCount;

            } else if (entry is FlashcardSubtemaCatalogEntry) {

              subtemasMap[entry.subtema] = entry.cardCount;

            }

          }



          var subtemas =

              ContentHierarchyUtils.sortAlphabetically(subtemasMap.keys);

          subtemas = ContentHierarchyUtils.filterSubtemas(subtemas, _busca);



          return Padding(

            padding: const EdgeInsets.all(16.0),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(

                  'Subtemas',

                  style: TextStyle(

                    fontSize: 24,

                    fontWeight: FontWeight.bold,

                    color: Color(0xFF1E3A8A),

                  ),

                ),

                const SizedBox(height: 12),

                TextField(

                  decoration: InputDecoration(

                    hintText: 'Buscar assunto (2+ letras)...',

                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),

                    suffixIcon: _busca.isNotEmpty

                        ? IconButton(

                            icon: const Icon(Icons.clear),

                            onPressed: () => setState(() => _busca = ''),

                          )

                        : null,

                    filled: true,

                    fillColor: Colors.white,

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(12),

                      borderSide: BorderSide.none,

                    ),

                  ),

                  onChanged: (v) => setState(() => _busca = v),

                ),

                const SizedBox(height: 16),

                Expanded(

                  child: subtemas.isEmpty

                      ? Center(

                          child: Text(

                            _busca.length >= 2

                                ? 'Nenhum subtema encontrado para "$_busca".'

                                : 'Nenhum subtema nesta matéria.',

                            textAlign: TextAlign.center,

                            style: const TextStyle(fontSize: 16, color: Colors.grey),

                          ),

                        )

                      : ListView.builder(

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

                                    color: const Color(0xFF1E3A8A)

                                        .withValues(alpha: 0.1),

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

                                subtitle: Text(

                                  '$total ${_isQuestoes ? 'questões' : 'flashcards'}',

                                ),

                                trailing: const Icon(

                                  Icons.arrow_forward_ios,

                                  color: Color(0xFF1E3A8A),

                                ),

                                onTap: () {

                                  Navigator.push(

                                    context,

                                    MaterialPageRoute(

                                      builder: (context) {

                                        if (_isQuestoes) {

                                          return QuestoesPage(

                                            userId: widget.userId,

                                            materia: widget.materia,

                                            subtema: subtema,

                                          );

                                        }

                                        return TelaFlashcards(

                                          userId: widget.userId,

                                          materia: widget.materia,

                                          subtema: subtema,

                                        );

                                      },

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


