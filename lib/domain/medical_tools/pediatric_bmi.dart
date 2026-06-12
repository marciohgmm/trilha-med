import 'pediatric_bmi_cdc_table.dart';

enum PediatricBiologicalSex { male, female }

enum PediatricBmiCategory {
  underweight,
  eutrophic,
  overweight,
  obesity,
  severeObesity,
}

class PediatricBmiReferenceRange {
  const PediatricBmiReferenceRange({
    required this.category,
    required this.percentileLabel,
    required this.classificationLabel,
  });

  final PediatricBmiCategory category;
  final String percentileLabel;
  final String classificationLabel;
}

class PediatricBmiEducationalGuide {
  const PediatricBmiEducationalGuide({
    required this.category,
    required this.title,
    required this.explanationParagraphs,
    required this.conductPoints,
    this.alertSigns = const [],
    this.emphasisNote,
  });

  final PediatricBmiCategory category;
  final String title;
  final List<String> explanationParagraphs;
  final List<String> conductPoints;
  final List<String> alertSigns;
  final String? emphasisNote;
}

class PediatricBmiResult {
  const PediatricBmiResult({
    required this.bmi,
    required this.weightKg,
    required this.heightCm,
    required this.ageMonths,
    required this.sex,
    required this.isUnderAgeTwo,
    this.estimatedPercentile,
    this.category,
    this.classificationLabel,
    this.interpolatedAnchor,
  });

  final double bmi;
  final double weightKg;
  final double heightCm;
  final int ageMonths;
  final PediatricBiologicalSex sex;
  final bool isUnderAgeTwo;

  /// Null se idade < 2 anos (sem classificação por percentil).
  final double? estimatedPercentile;
  final PediatricBmiCategory? category;
  final String? classificationLabel;
  final CdcBmiPercentileAnchor? interpolatedAnchor;

  double get heightM => heightCm / 100;

  bool get hasPercentileClassification =>
      !isUnderAgeTwo && estimatedPercentile != null && category != null;

  PediatricBmiEducationalGuide? get guide =>
      category != null ? pediatricBmiGuideFor(category!) : null;

  String get ageLabel {
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    if (months == 0) return '$years ano(s)';
    return '$years ano(s) e $months mês(es)';
  }
}

const String pediatricBmiAgeSexDisclaimer =
    'No paciente pediátrico, o IMC deve ser interpretado de acordo com idade e sexo, '
    'usando curvas/percentis apropriados. O valor isolado do IMC não deve ser '
    'interpretado da mesma forma que no adulto.';

const String pediatricBmiEducationalDisclaimer =
    'Esta ferramenta tem finalidade educativa e de triagem, não substituindo '
    'avaliação clínica, curva de crescimento e exame profissional.';

const String pediatricBmiPercentileDisclaimer =
    'Percentil estimado com base na referência CDC 2000 (curvas BMI-for-age), '
    'com interpolação entre marcos anuais. Para decisão clínica, prefira curvas '
    'oficiais/plotagem em cartão de crescimento.';

const String pediatricBmiUnderTwoWarning =
    'Esta calculadora é indicada para crianças e adolescentes de 2 a 19 anos. '
    'Para menores de 2 anos, a avaliação nutricional deve usar parâmetros específicos '
    '(por exemplo, relação peso/estatura e curvas da faixa etária), não o IMC '
    'interpretado como no adulto.';

const List<PediatricBmiReferenceRange> pediatricBmiReferenceRanges = [
  PediatricBmiReferenceRange(
    category: PediatricBmiCategory.underweight,
    percentileLabel: 'Abaixo do percentil 5',
    classificationLabel: 'Baixo peso',
  ),
  PediatricBmiReferenceRange(
    category: PediatricBmiCategory.eutrophic,
    percentileLabel: 'Percentil 5 a menor que 85',
    classificationLabel: 'Peso adequado / eutrofia',
  ),
  PediatricBmiReferenceRange(
    category: PediatricBmiCategory.overweight,
    percentileLabel: 'Percentil 85 a menor que 95',
    classificationLabel: 'Sobrepeso',
  ),
  PediatricBmiReferenceRange(
    category: PediatricBmiCategory.obesity,
    percentileLabel: 'Percentil 95 ou mais',
    classificationLabel: 'Obesidade',
  ),
  PediatricBmiReferenceRange(
    category: PediatricBmiCategory.severeObesity,
    percentileLabel: 'Obesidade grave',
    classificationLabel: '120% do P95 ou IMC ≥ 35 kg/m²',
  ),
];

int? parsePediatricAgeMonths({
  required String yearsText,
  required String monthsText,
}) {
  final years = int.tryParse(yearsText.trim());
  if (years == null || years < 0) return null;

  final monthsRaw = monthsText.trim();
  final extraMonths =
      monthsRaw.isEmpty ? 0 : int.tryParse(monthsRaw);
  if (extraMonths == null || extraMonths < 0 || extraMonths > 11) {
    return null;
  }

  return years * 12 + extraMonths;
}

PediatricBmiResult calculatePediatricBmi({
  required double weightKg,
  required double heightCm,
  required int ageMonths,
  required PediatricBiologicalSex sex,
}) {
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (heightCm < 50 || heightCm > 220) {
    throw ArgumentError('Altura deve estar entre 50 cm e 220 cm.');
  }
  if (ageMonths < 0 || ageMonths > 240) {
    throw ArgumentError('Idade fora da faixa suportada (0 a 20 anos).');
  }

  final heightM = heightCm / 100;
  final bmi = weightKg / (heightM * heightM);
  final rounded = double.parse(bmi.toStringAsFixed(1));

  final isUnderAgeTwo = ageMonths < 24;
  if (isUnderAgeTwo) {
    return PediatricBmiResult(
      bmi: rounded,
      weightKg: weightKg,
      heightCm: heightCm,
      ageMonths: ageMonths,
      sex: sex,
      isUnderAgeTwo: true,
    );
  }

  if (ageMonths > 228) {
    throw ArgumentError(
      'Ferramenta indicada para 2 a 19 anos. Idade acima de 19 anos completos.',
    );
  }

  final anchor = interpolateCdcAnchors(sex, ageMonths);
  final percentile = estimateBmiPercentileFromAnchors(rounded, anchor);
  final category = classifyPediatricBmiFromPercentile(
    percentile,
    bmi: rounded,
    p95: anchor.p95,
  );

  return PediatricBmiResult(
    bmi: rounded,
    weightKg: weightKg,
    heightCm: heightCm,
    ageMonths: ageMonths,
    sex: sex,
    isUnderAgeTwo: false,
    estimatedPercentile: percentile,
    category: category,
    classificationLabel: _classificationLabel(category),
    interpolatedAnchor: anchor,
  );
}

String _classificationLabel(PediatricBmiCategory category) {
  return pediatricBmiReferenceRanges
      .firstWhere((r) => r.category == category)
      .classificationLabel;
}

String pediatricBmiSexLabel(PediatricBiologicalSex sex) {
  return sex == PediatricBiologicalSex.male ? 'Masculino' : 'Feminino';
}

PediatricBmiEducationalGuide pediatricBmiGuideFor(PediatricBmiCategory category) {
  switch (category) {
    case PediatricBmiCategory.underweight:
      return const PediatricBmiEducationalGuide(
        category: PediatricBmiCategory.underweight,
        title: 'Abaixo do percentil 5 — baixo peso',
        explanationParagraphs: [
          'Pode sugerir magreza/baixo peso e deve ser avaliado no contexto clínico, '
              'dietético e do crescimento.',
          'Possíveis contribuintes: baixa ingestão calórica, condições crônicas, '
              'distúrbios de absorção, causas endocrinológicas, doenças sistêmicas '
              'e vulnerabilidade social.',
        ],
        alertSigns: [
          'Queda ou estagnação na curva de crescimento',
          'Inapetência persistente',
          'Sinais de desnutrição ou anemia',
          'Diarreia crônica ou perda ponderal',
        ],
        conductPoints: [
          'Revisar curva de crescimento e velocidade ponderoestatural.',
          'Avaliar evolução ponderoestatural nas consultas seriadas.',
          'Investigar ingestão alimentar e contexto familiar.',
          'Pesquisar sinais clínicos associados.',
          'Considerar avaliação médica e nutricional.',
        ],
      );
    case PediatricBmiCategory.eutrophic:
      return const PediatricBmiEducationalGuide(
        category: PediatricBmiCategory.eutrophic,
        title: 'Percentil 5 a 84 — peso adequado',
        explanationParagraphs: [
          'Corresponde à faixa esperada de referência para idade e sexo.',
          'Manter vigilância do crescimento ao longo do tempo.',
        ],
        conductPoints: [
          'Manter alimentação equilibrada e variada.',
          'Sono adequado para a faixa etária.',
          'Atividade física regular e lúdica.',
          'Acompanhar curva de crescimento nas consultas de rotina.',
        ],
      );
    case PediatricBmiCategory.overweight:
      return const PediatricBmiEducationalGuide(
        category: PediatricBmiCategory.overweight,
        title: 'Percentil 85 a 94 — sobrepeso',
        explanationParagraphs: [
          'Corresponde a sobrepeso pediátrico, com maior risco futuro '
              'cardiometabólico se não houver mudança de hábitos.',
        ],
        conductPoints: [
          'Revisar hábitos alimentares (porções, ultraprocessados, bebidas açucaradas).',
          'Estimular atividade física regular.',
          'Envolver a família no plano de mudanças sustentáveis.',
          'Avaliar contexto comportamental e tempo de tela.',
          'Acompanhar crescimento e evolução clínica.',
        ],
      );
    case PediatricBmiCategory.obesity:
      return const PediatricBmiEducationalGuide(
        category: PediatricBmiCategory.obesity,
        title: 'Percentil ≥ 95 — obesidade',
        explanationParagraphs: [
          'Corresponde a obesidade pediátrica, com risco aumentado de hipertensão, '
              'resistência à insulina, dislipidemia, esteatose hepática, apneia do sono '
              'e impacto psicossocial.',
        ],
        conductPoints: [
          'Abordagem familiar e plano multiprofissional.',
          'Rastrear comorbidades conforme idade e achados clínicos.',
          'Orientar mudanças sustentáveis no estilo de vida.',
          'Programar seguimento clínico regular.',
        ],
      );
    case PediatricBmiCategory.severeObesity:
      return const PediatricBmiEducationalGuide(
        category: PediatricBmiCategory.severeObesity,
        title: 'Obesidade grave',
        explanationParagraphs: [
          'Representa maior gravidade clínica e maior risco de complicações.',
          'Critérios: IMC ≥ 35 kg/m² ou ≥ 120% do valor do percentil 95 para idade/sexo.',
        ],
        emphasisNote:
            'Necessita avaliação mais cuidadosa e acompanhamento especializado. '
            'Discutir estratégias terapêuticas individualizadas com equipe pediátrica.',
        conductPoints: [
          'Priorizar avaliação clínica completa e estratificação de risco.',
          'Investigar comorbidades e impacto na qualidade de vida.',
          'Intervenção multiprofissional com seguimento próximo.',
          'Considerar encaminhamento a serviços especializados em obesidade pediátrica.',
        ],
      );
  }
}
