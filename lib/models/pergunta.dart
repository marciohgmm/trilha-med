class Pergunta {
  final String id;
  final String enunciado;
  final String resposta;
  final String materia;
  final String tema;
  final String subtema;
  final int dificuldade;
  final List<String> tags;

  // 🔥 NOVOS CAMPOS (Firebase)
  final String imagemPergunta;
  final String imagemResposta;
  final String explicacao;

  Pergunta({
    required this.id,
    required this.enunciado,
    required this.resposta,
    required this.materia,
    required this.tema,
    required this.subtema,
    this.dificuldade = 1,
    this.tags = const [],

    // novos
    this.imagemPergunta = '',
    this.imagemResposta = '',
    this.explicacao = '',
  });

  // 🔥 CONVERTER FIREBASE → OBJETO
  factory Pergunta.fromMap(String id, Map<String, dynamic> map) {
    return Pergunta(
      id: id,
      enunciado: map['pergunta'] ?? '',
      resposta: map['resposta'] ?? '',
      materia: map['materia'] ?? '',
      tema: map['tema'] ?? '',
      subtema: map['subtema'] ?? '',
      dificuldade: map['dificuldade'] ?? 1,
      tags: List<String>.from(map['tags'] ?? []),

      imagemPergunta: map['imagemPergunta'] ?? '',
      imagemResposta: map['imagemResposta'] ?? '',
      explicacao: map['explicacao'] ?? '',
    );
  }

  // 🔥 CONVERTER OBJETO → FIREBASE
  Map<String, dynamic> toMap() {
    return {
      'pergunta': enunciado,
      'resposta': resposta,
      'materia': materia,
      'tema': tema,
      'subtema': subtema,
      'dificuldade': dificuldade,
      'tags': tags,

      'imagemPergunta': imagemPergunta,
      'imagemResposta': imagemResposta,
      'explicacao': explicacao,
    };
  }
}