import 'package:flutter/material.dart';

import 'admin_subtemas_page.dart';

/// Tela legada — redireciona para [AdminSubtemasPage] (matéria → subtema).
class AdminTemasPage extends StatelessWidget {
  final String materia;

  const AdminTemasPage({
    super.key,
    required this.materia,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSubtemasPage(materia: materia);
  }
}
