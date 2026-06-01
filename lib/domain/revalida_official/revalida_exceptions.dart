/// Exceção quando o banco não tem questões suficientes para a prova oficial.
class RevalidaInsufficientQuestionsException implements Exception {
  RevalidaInsufficientQuestionsException({
    required this.available,
    required this.required,
  });

  final int available;
  final int required;

  @override
  String toString() =>
      'Questões insuficientes: $available disponíveis, $required necessárias.';
}
