import 'package:flutter/material.dart';

import 'admin_questoes_subtemas_page.dart';

/// Tela legada — redireciona para [AdminQuestoesSubtemasPage].
class AdminQuestoesTemasPage extends StatelessWidget {
  final String materia;

  const AdminQuestoesTemasPage({
    super.key,
    required this.materia,
  });

  @override
  Widget build(BuildContext context) {
    return AdminQuestoesSubtemasPage(materia: materia);
  }
}
