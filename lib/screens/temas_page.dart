import 'package:flutter/material.dart';

import 'subtemas_page.dart';

/// Tela legada — redireciona para [SubtemasPage] (matéria → subtema).
class TemasPage extends StatelessWidget {
  final String userId;
  final String materia;
  final String collectionName;

  const TemasPage({
    super.key,
    required this.userId,
    required this.materia,
    this.collectionName = 'flashcards',
  });

  @override
  Widget build(BuildContext context) {
    return SubtemasPage(
      userId: userId,
      materia: materia,
      collectionName: collectionName,
    );
  }
}
