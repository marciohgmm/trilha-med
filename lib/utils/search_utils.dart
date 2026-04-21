/// Gera um array de termos pesquisáveis (prefixos) para um texto.
Set<String> gerarSearchTerms(String texto) {
  if (texto.isEmpty) return <String>{};

  final min = 2;
  final max = 4;

  final sanitized =
      texto.trim().toLowerCase().replaceAll(RegExp(r'[^a-záàãâéèêíìóòõôúùç]'), '');

  final terms = <String>{};

  final limit = sanitized.length;
  for (int i = 0; i < limit; i++) {
    for (int j = i + min; j <= limit && j <= i + max; j++) {
      final substr = sanitized.substring(i, j);
      if (substr.isNotEmpty) {
        terms.add(substr);
      }
    }
  }

  // Adiciona o termo completo
  terms.add(sanitized);

  return terms;
}