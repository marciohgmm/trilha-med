/// Desempenho OSCE por especialidade (média das avaliações finalizadas).
class SpecialtyPerformance {
  final String key;
  final String name;
  final int overallPercent;
  final Map<String, int> skills;

  /// Quantidade de estações OSCE avaliadas nesta especialidade.
  final int stationCount;

  const SpecialtyPerformance({
    required this.key,
    required this.name,
    required this.overallPercent,
    required this.skills,
    this.stationCount = 0,
  });

  bool get hasData => stationCount > 0;

  static const specialties = <String, String>{
    'clinica_medica': 'Clínica Médica',
    'clinica_cirurgica': 'Clínica Cirúrgica',
    'mfc': 'Medicina da Família e Comunidade',
    'pediatria': 'Pediatria',
    'go': 'Ginecologia e Obstetrícia',
  };

  factory SpecialtyPerformance.fromMap(String key, Map<String, dynamic> map) {
    final skillsRaw = map['skills'];
    final skills = <String, int>{};
    if (skillsRaw is Map) {
      skillsRaw.forEach((k, v) {
        skills[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return SpecialtyPerformance(
      key: key,
      name: specialties[key] ?? key,
      overallPercent: (map['overall'] as num?)?.toInt() ?? 0,
      skills: skills,
    );
  }

  Map<String, dynamic> toMap() => {
        'overall': overallPercent,
        'skills': skills,
        'stationCount': stationCount,
      };

  String? get weakestSkill {
    if (skills.isEmpty) return null;
    var minKey = skills.keys.first;
    var minVal = skills[minKey]!;
    for (final e in skills.entries) {
      if (e.value < minVal) {
        minVal = e.value;
        minKey = e.key;
      }
    }
    return _skillLabel(minKey);
  }

  static String skillLabel(String key) => _skillLabel(key);

  static String _skillLabel(String key) {
    const labels = {
      'apresentacao': 'Apresentação',
      'anamnese': 'Anamnese',
      'exame_fisico': 'Exame físico',
      'laboratorio': 'Laboratório',
      'imagem': 'Imagem',
      'diagnostico': 'Diagnóstico',
      'tratamento': 'Tratamento',
      'orientacoes': 'Orientações',
    };
    return labels[key] ?? key;
  }

  static const skillKeys = [
    'apresentacao',
    'anamnese',
    'exame_fisico',
    'laboratorio',
    'imagem',
    'diagnostico',
    'tratamento',
    'orientacoes',
  ];
}
