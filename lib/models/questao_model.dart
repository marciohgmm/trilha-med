import 'package:cloud_firestore/cloud_firestore.dart';

class QuestaoAlternativa {
  final String id;
  final String texto;

  const QuestaoAlternativa({
    required this.id,
    required this.texto,
  });

  factory QuestaoAlternativa.fromMap(Map<String, dynamic> map) {
    return QuestaoAlternativa(
      id: map['id']?.toString() ?? '',
      texto: map['texto']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'texto': texto,
    };
  }
}

class QuestaoModel {
  final String id;
  final String temaId;
  final String temaSlug;
  final String materiaId;
  final String materia;
  final String tema;
  final String subtema;
  final String? flashcardId;
  final String enunciado;
  final List<QuestaoAlternativa> alternativas;
  final String corretaId;
  final String explicacaoGeral;
  final String explicacaoCorreta;
  final Map<String, String> explicacoesErradas;
  final Map<String, String> justificativasPorAlternativa;
  final String dificuldade;
  final String status;
  final List<String> tags;
  final bool ativo; // mantido por compatibilidade; use status quando possível
  final DateTime createdAt;
  final DateTime updatedAt;
  final int ordem;

  QuestaoModel({
    required this.id,
    required this.temaId,
    required this.temaSlug,
    required this.materiaId,
    required this.materia,
    required this.tema,
    required this.subtema,
    required this.flashcardId,
    required this.enunciado,
    required this.alternativas,
    required this.corretaId,
    required this.explicacaoGeral,
    required this.explicacaoCorreta,
    required this.explicacoesErradas,
    required this.justificativasPorAlternativa,
    required this.dificuldade,
    required this.status,
    required this.tags,
    required this.ativo,
    required this.createdAt,
    required this.updatedAt,
    required this.ordem,
  });

  factory QuestaoModel.fromMap(String id, Map<String, dynamic> map) {
    final alternativasRaw = map['alternativas'];
    final explicacoesErradasRaw = map['explicacoesErradas'];
    final justificativasRaw = map['justificativasPorAlternativa'];
    final tagsRaw = map['tags'];

    return QuestaoModel(
      id: id,
      temaId: map['temaId']?.toString() ?? '',
      temaSlug:
          map['temaSlug']?.toString() ?? slugify(map['tema']?.toString() ?? ''),
      materiaId: map['materiaId']?.toString() ?? '',
      materia: map['materia']?.toString() ?? '',
      tema: map['tema']?.toString() ?? '',
      subtema: map['subtema']?.toString() ?? '',
      flashcardId: (map['flashcardId'] ?? '').toString().trim().isEmpty
          ? null
          : map['flashcardId']?.toString(),
      enunciado: map['enunciado']?.toString() ?? '',
      alternativas: alternativasRaw is List
          ? alternativasRaw
              .whereType<Map<String, dynamic>>()
              .map(QuestaoAlternativa.fromMap)
              .toList()
          : <QuestaoAlternativa>[],
      corretaId: map['corretaId']?.toString() ?? '',
      explicacaoGeral: map['explicacao']?.toString() ??
          map['explicacaoGeral']?.toString() ??
          '',
      explicacaoCorreta: map['explicacaoCorreta']?.toString() ?? '',
      explicacoesErradas: explicacoesErradasRaw is Map
          ? Map<String, String>.fromEntries(
              explicacoesErradasRaw.entries.map(
                (entry) => MapEntry(
                    entry.key.toString(), entry.value?.toString() ?? ''),
              ),
            )
          : <String, String>{},
      justificativasPorAlternativa: justificativasRaw is Map
          ? Map<String, String>.fromEntries(
              justificativasRaw.entries.map(
                (entry) => MapEntry(
                    entry.key.toString(), entry.value?.toString() ?? ''),
              ),
            )
          : <String, String>{},
      dificuldade: map['dificuldade']?.toString() ?? 'médio',
      status: map['status']?.toString() ??
          ((map['ativo'] is bool && map['ativo'] == false)
              ? 'inativo'
              : 'ativo'),
      tags: tagsRaw is List
          ? tagsRaw
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
          : <String>[],
      ativo: map['ativo'] is bool ? map['ativo'] as bool : true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']) ?? DateTime.now(),
      ordem: map['ordem'] is int ? map['ordem'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temaId': temaId,
      'temaSlug': temaSlug,
      'materiaId': materiaId,
      'materia': materia,
      'tema': tema,
      'subtema': subtema,
      'flashcardId': flashcardId,
      'enunciado': enunciado,
      'alternativas': alternativas.map((alt) => alt.toMap()).toList(),
      'corretaId': corretaId,
      'explicacao': explicacaoGeral,
      'explicacaoCorreta': explicacaoCorreta,
      'explicacoesErradas': explicacoesErradas,
      'justificativasPorAlternativa': justificativasPorAlternativa,
      'dificuldade': dificuldade,
      'status': status,
      'tags': tags,
      'ativo': ativo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ordem': ordem,
    };
  }

  /// Questões visíveis na lista de estudo (exclui rascunho/inativo explícitos).
  bool get disponivelParaEstudo {
    if (!ativo) return false;
    final s = status.trim().toLowerCase();
    if (s == 'inativo' || s == 'rascunho' || s == 'arquivado') {
      return false;
    }
    return true;
  }

  QuestaoAlternativa? get alternativaCorreta {
    return alternativas.firstWhere(
      (alt) => alt.id == corretaId,
      orElse: () => alternativas.isNotEmpty
          ? alternativas.first
          : QuestaoAlternativa(id: '', texto: ''),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
