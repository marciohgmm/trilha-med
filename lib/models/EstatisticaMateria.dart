class EstatisticaMateria {
  final String materia;
  int percentualEstudado;
  int vezesRevisado;

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
      materia: json['materia'] ?? '',
      percentualEstudado: json['percentualEstudado'] ?? 0,
      vezesRevisado: json['vezesRevisado'] ?? 0,
    );
  }
}
