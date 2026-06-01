/// Usuário já enviou reporte desta questão.
class QuestaoReportAlreadyExistsException implements Exception {
  @override
  String toString() => 'Você já reportou esta questão.';
}
