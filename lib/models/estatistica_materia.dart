class EstatisticaMateria {
  final String materia;
  final int percentualEstudado; // imutável, se não for mudar
  final int vezesRevisado; // imutável, se não for mudar

  EstatisticaMateria({
    required this.materia,
    this.percentualEstudado = 0,
    this.vezesRevisado = 0,
  });

  Map<String, dynamic> toJson() => {
        'materia': materia,
        'percentualEstudado': percentualEstudado,
        'vezesRevisado': vezesRevisado,
      };

  factory EstatisticaMateria.fromJson(Map<String, dynamic> json) {
    return EstatisticaMateria(
      materia: json['materia'] as String,
      percentualEstudado: (json['percentualEstudado'] as num?)?.toInt() ?? 0,
      vezesRevisado: (json['vezesRevisado'] as num?)?.toInt() ?? 0,
    );
  }
}
