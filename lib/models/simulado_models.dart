import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuração escolhida antes de iniciar o simulado.
class SimuladoFiltros {
  final int quantidade;
  final bool todasMaterias;
  final List<String> materiasSelecionadas;
  final SimuladoTipoQuestoes tipoQuestoes;
  final SimuladoStatusResolucao statusResolucao;

  const SimuladoFiltros({
    required this.quantidade,
    required this.todasMaterias,
    required this.materiasSelecionadas,
    required this.tipoQuestoes,
    required this.statusResolucao,
  });

  Map<String, dynamic> toMap() => {
        'quantidade': quantidade,
        'todasMaterias': todasMaterias,
        'materias': materiasSelecionadas,
        'tipoQuestoes': tipoQuestoes.name,
        'statusResolucao': statusResolucao.name,
      };

  factory SimuladoFiltros.fromMap(Map<String, dynamic> m) {
    return SimuladoFiltros(
      quantidade: (m['quantidade'] as num?)?.toInt() ?? 25,
      todasMaterias: m['todasMaterias'] == true,
      materiasSelecionadas: (m['materias'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tipoQuestoes: SimuladoTipoQuestoes.values.firstWhere(
        (e) => e.name == m['tipoQuestoes'],
        orElse: () => SimuladoTipoQuestoes.todas,
      ),
      statusResolucao: SimuladoStatusResolucao.values.firstWhere(
        (e) => e.name == m['statusResolucao'],
        orElse: () => SimuladoStatusResolucao.apenasNaoResolvidas,
      ),
    );
  }
}

enum SimuladoTipoQuestoes {
  todas,
  apenasErradas,
}

enum SimuladoStatusResolucao {
  apenasNaoResolvidas,
  incluirResolvidas,
}

/// Progresso de uma questão pelo usuário (espelho de progresso_questoes).
class ProgressoQuestaoUsuario {
  final String questaoId;
  final bool acertou;
  final DateTime? respondidaEm;

  const ProgressoQuestaoUsuario({
    required this.questaoId,
    required this.acertou,
    this.respondidaEm,
  });

  factory ProgressoQuestaoUsuario.fromMap(String id, Map<String, dynamic> m) {
    return ProgressoQuestaoUsuario(
      questaoId: id,
      acertou: m['acertou'] == true,
      respondidaEm: parseFirestoreDate(m['respondidaEm']),
    );
  }
}

/// Resumo salvo ao finalizar o simulado.
class SimuladoHistorico {
  final String id;
  final String userId;
  final SimuladoFiltros filtros;
  final int totalQuestoes;
  final int acertos;
  final int erros;
  final int naoRespondidas;
  final double percentualAcertos;
  final int tempoSegundos;
  final List<String> questaoIds;
  final DateTime criadoEm;

  const SimuladoHistorico({
    required this.id,
    required this.userId,
    required this.filtros,
    required this.totalQuestoes,
    required this.acertos,
    required this.erros,
    required this.naoRespondidas,
    required this.percentualAcertos,
    required this.tempoSegundos,
    required this.questaoIds,
    required this.criadoEm,
  });

  int get respondidas => acertos + erros;

  factory SimuladoHistorico.fromDoc(String id, Map<String, dynamic> m) {
    return SimuladoHistorico(
      id: id,
      userId: m['userId']?.toString() ?? '',
      filtros: SimuladoFiltros.fromMap(
        Map<String, dynamic>.from(m['filtros'] as Map? ?? {}),
      ),
      totalQuestoes: (m['totalQuestoes'] as num?)?.toInt() ?? 0,
      acertos: (m['acertos'] as num?)?.toInt() ?? 0,
      erros: (m['erros'] as num?)?.toInt() ?? 0,
      naoRespondidas: (m['naoRespondidas'] as num?)?.toInt() ?? 0,
      percentualAcertos: (m['percentualAcertos'] as num?)?.toDouble() ?? 0,
      tempoSegundos: (m['tempoSegundos'] as num?)?.toInt() ?? 0,
      questaoIds: (m['questaoIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      criadoEm: parseFirestoreDate(m['criadoEm']) ?? DateTime.now(),
    );
  }
}

/// Converte [Timestamp] ou ISO string do Firestore.
DateTime? parseFirestoreDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class SimuladoInsufficientQuestionsException implements Exception {
  final int disponiveis;
  final int solicitadas;

  SimuladoInsufficientQuestionsException({
    required this.disponiveis,
    required this.solicitadas,
  });

  @override
  String toString() =>
      'Encontramos $disponiveis questão(ões) para os filtros, '
      'mas você pediu $solicitadas.';
}
