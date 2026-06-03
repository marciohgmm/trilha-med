/// IMC adulto — classificação OMS e conteúdo educacional para estudo.
enum AdultBmiCategory {
  underweight,
  eutrophic,
  overweight,
  obesity1,
  obesity2,
  obesity3,
}

class AdultBmiReferenceRange {
  const AdultBmiReferenceRange({
    required this.category,
    required this.rangeLabel,
    required this.classificationLabel,
    required this.minBmi,
    this.maxBmiExclusive,
  });

  final AdultBmiCategory category;
  final String rangeLabel;
  final String classificationLabel;
  final double minBmi;
  final double? maxBmiExclusive;

  bool contains(double bmi) {
    if (bmi < minBmi) return false;
    if (maxBmiExclusive == null) return true;
    return bmi < maxBmiExclusive!;
  }
}

class AdultBmiEducationalGuide {
  const AdultBmiEducationalGuide({
    required this.category,
    required this.title,
    required this.explanationParagraphs,
    required this.conductPoints,
    this.alertSigns = const [],
    this.emphasisNote,
  });

  final AdultBmiCategory category;
  final String title;
  final List<String> explanationParagraphs;
  final List<String> conductPoints;
  final List<String> alertSigns;
  final String? emphasisNote;
}

class AdultBmiResult {
  const AdultBmiResult({
    required this.bmi,
    required this.classification,
    required this.category,
    required this.weightKg,
    required this.heightCm,
  });

  final double bmi;
  final String classification;
  final AdultBmiCategory category;
  final double weightKg;
  final double heightCm;

  double get heightM => heightCm / 100;

  AdultBmiEducationalGuide get guide => adultBmiGuideFor(category);

  AdultBmiReferenceRange get referenceRange =>
      adultBmiReferenceRanges.firstWhere((r) => r.category == category);
}

/// Faixas de referência OMS para adultos.
const List<AdultBmiReferenceRange> adultBmiReferenceRanges = [
  AdultBmiReferenceRange(
    category: AdultBmiCategory.underweight,
    rangeLabel: 'Abaixo de 18,5',
    classificationLabel: 'Baixo peso',
    minBmi: 0,
    maxBmiExclusive: 18.5,
  ),
  AdultBmiReferenceRange(
    category: AdultBmiCategory.eutrophic,
    rangeLabel: '18,5 a 24,9',
    classificationLabel: 'Eutrofia / peso adequado',
    minBmi: 18.5,
    maxBmiExclusive: 25,
  ),
  AdultBmiReferenceRange(
    category: AdultBmiCategory.overweight,
    rangeLabel: '25,0 a 29,9',
    classificationLabel: 'Sobrepeso',
    minBmi: 25,
    maxBmiExclusive: 30,
  ),
  AdultBmiReferenceRange(
    category: AdultBmiCategory.obesity1,
    rangeLabel: '30,0 a 34,9',
    classificationLabel: 'Obesidade grau I',
    minBmi: 30,
    maxBmiExclusive: 35,
  ),
  AdultBmiReferenceRange(
    category: AdultBmiCategory.obesity2,
    rangeLabel: '35,0 a 39,9',
    classificationLabel: 'Obesidade grau II',
    minBmi: 35,
    maxBmiExclusive: 40,
  ),
  AdultBmiReferenceRange(
    category: AdultBmiCategory.obesity3,
    rangeLabel: '40,0 ou mais',
    classificationLabel: 'Obesidade grau III',
    minBmi: 40,
  ),
];

const String adultBmiScreeningDisclaimer =
    'O IMC é uma ferramenta de triagem. Deve ser interpretado junto com a '
    'avaliação clínica, composição corporal, circunferência abdominal e '
    'presença de comorbidades. Não substitui consulta médica nem define '
    'diagnóstico isoladamente.';

AdultBmiCategory classifyAdultBmiCategory(double bmi) {
  if (bmi < 18.5) return AdultBmiCategory.underweight;
  if (bmi < 25) return AdultBmiCategory.eutrophic;
  if (bmi < 30) return AdultBmiCategory.overweight;
  if (bmi < 35) return AdultBmiCategory.obesity1;
  if (bmi < 40) return AdultBmiCategory.obesity2;
  return AdultBmiCategory.obesity3;
}

String classifyAdultBmi(double bmi) {
  return adultBmiReferenceRanges
      .firstWhere((r) => r.category == classifyAdultBmiCategory(bmi))
      .classificationLabel;
}

/// Aceita altura em cm (ex.: 175) ou em metros (ex.: 1,75).
double? parseAdultHeightToCm(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null || value <= 0) return null;

  // Valores típicos em metros ficam ≤ 3; em cm, geralmente ≥ 50.
  if (value <= 3) {
    return value * 100;
  }
  return value;
}

AdultBmiResult calculateAdultBmi({
  required double weightKg,
  required double heightCm,
}) {
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (heightCm < 50 || heightCm > 250) {
    throw ArgumentError('Altura deve estar entre 50 cm e 250 cm.');
  }

  final heightM = heightCm / 100;
  final bmi = weightKg / (heightM * heightM);
  final rounded = double.parse(bmi.toStringAsFixed(1));
  final category = classifyAdultBmiCategory(rounded);

  return AdultBmiResult(
    bmi: rounded,
    classification: classifyAdultBmi(rounded),
    category: category,
    weightKg: weightKg,
    heightCm: heightCm,
  );
}

AdultBmiEducationalGuide adultBmiGuideFor(AdultBmiCategory category) {
  switch (category) {
    case AdultBmiCategory.underweight:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.underweight,
        title: 'Baixo peso — o que considerar',
        explanationParagraphs: [
          'O IMC abaixo de 18,5 sugere baixo peso e pode estar relacionado a '
              'desnutrição, baixa ingestão calórica, doença crônica, transtornos '
              'alimentares, causas gastrointestinais, endocrinológicas ou outras '
              'condições clínicas.',
          'A interpretação deve ser individualizada, com investigação da causa '
              'e avaliação do estado nutricional global.',
        ],
        alertSigns: [
          'Perda de peso involuntária',
          'Inapetência persistente',
          'Anemia ou astenia importante',
          'Diarreia crônica',
          'Febre prolongada',
          'Fraqueza com impacto funcional',
        ],
        conductPoints: [
          'Revisar história clínica e curva de peso (perda ponderal).',
          'Avaliar ingestão alimentar e contexto psicossocial.',
          'Investigar causas orgânicas conforme suspeita clínica.',
          'Considerar exames laboratoriais orientados pelo quadro.',
          'Orientar acompanhamento médico e nutricional.',
        ],
      );
    case AdultBmiCategory.eutrophic:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.eutrophic,
        title: 'Eutrofia — peso adequado',
        explanationParagraphs: [
          'O IMC está na faixa habitual de referência para adultos (18,5 a 24,9).',
          'Isso sugere adequação ponderal em termos populacionais, mas ainda '
              'depende do contexto clínico individual.',
        ],
        conductPoints: [
          'Reforçar manutenção de hábitos saudáveis.',
          'Alimentação equilibrada e variedade nutricional.',
          'Atividade física regular conforme capacidade.',
          'Acompanhar peso e comorbidades ao longo do tempo.',
        ],
      );
    case AdultBmiCategory.overweight:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.overweight,
        title: 'Sobrepeso — risco e conduta inicial',
        explanationParagraphs: [
          'O IMC entre 25 e 29,9 indica sobrepeso, com maior risco '
              'cardiometabólico, especialmente se houver aumento da circunferência '
              'abdominal, dislipidemia, hipertensão ou intolerância à glicose.',
        ],
        conductPoints: [
          'Orientar mudanças sustentáveis na alimentação.',
          'Estimular atividade física regular.',
          'Avaliar pressão arterial, glicemia e perfil lipídico.',
          'Mensurar circunferência abdominal quando pertinente.',
          'Agendar acompanhamento clínico periódico.',
        ],
      );
    case AdultBmiCategory.obesity1:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.obesity1,
        title: 'Obesidade grau I',
        explanationParagraphs: [
          'Obesidade grau I (IMC 30,0 a 34,9) aumenta o risco de hipertensão, '
              'diabetes tipo 2, apneia do sono, doença cardiovascular, esteatose '
              'hepática e outras complicações.',
        ],
        conductPoints: [
          'Intervenção intensiva em estilo de vida (dieta, movimento, sono).',
          'Rastrear comorbidades cardiometabólicas.',
          'Avaliar circunferência abdominal e sintomas associados.',
          'Considerar encaminhamento multiprofissional (médico, nutrição, educação física).',
          'Discutir metas realistas e acompanhamento contínuo.',
        ],
      );
    case AdultBmiCategory.obesity2:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.obesity2,
        title: 'Obesidade grau II',
        explanationParagraphs: [
          'Obesidade grau II (IMC 35,0 a 39,9) representa risco clínico mais '
              'elevado para complicações metabólicas, cardiovasculares e '
              'restrição funcional.',
        ],
        conductPoints: [
          'Plano estruturado de mudança de estilo de vida com metas progressivas.',
          'Rastreio ampliado de comorbidades (glicemia, lipídios, PA, função hepática).',
          'Avaliar apneia do sono se houver sintomas sugestivos.',
          'Encaminhamento multiprofissional recomendado.',
          'Em casos selecionados, discutir tratamento medicamentoso com especialista.',
        ],
      );
    case AdultBmiCategory.obesity3:
      return const AdultBmiEducationalGuide(
        category: AdultBmiCategory.obesity3,
        title: 'Obesidade grau III',
        explanationParagraphs: [
          'Obesidade grau III (IMC ≥ 40) associa-se a risco clínico ainda mais '
              'elevado e maior probabilidade de comorbidades graves.',
        ],
        emphasisNote:
            'Necessita de avaliação médica cuidadosa e plano terapêutico '
            'individualizado. Em casos selecionados, pode haver indicação de '
            'tratamento medicamentoso e avaliação especializada para outras '
            'estratégias terapêuticas.',
        conductPoints: [
          'Priorizar avaliação clínica completa e estratificação de risco.',
          'Investigar comorbidades e impacto na qualidade de vida.',
          'Intervenção multiprofissional com seguimento próximo.',
          'Considerar terapias adjuvantes conforme diretriz e perfil do paciente.',
          'Monitorar evolução ponderal e parâmetros metabólicos regularmente.',
        ],
      );
  }
}
