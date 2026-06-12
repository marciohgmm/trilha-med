import 'dart:math' as math;

/// Divisor da fórmula de Mosteller (altura cm × peso kg).
const double mostellerDivisor = 3600;

const String bsaEducationalDisclaimer =
    'Esta ferramenta calcula a área de superfície corporal total (ASC) e tem '
    'finalidade educativa e de apoio ao raciocínio clínico. Não substitui '
    'avaliação profissional.';

const String bsaMostellerDidacticText =
    'A área de superfície corporal é estimada usando peso e altura. Na fórmula '
    'de Mosteller, multiplica-se a altura em centímetros pelo peso em quilogramas, '
    'divide-se por 3600 e depois calcula-se a raiz quadrada do valor encontrado.';

const String bsaFormulaCardText =
    'ASC (m²) = √[(altura em cm × peso em kg) ÷ 3600]\n\n'
    'Fórmula de Mosteller — referência amplamente usada na prática clínica.';

const String bsaBurnsClarificationText =
    'Esta calculadora fornece a ASC total do paciente. Isso não é o mesmo que '
    'calcular a porcentagem de superfície corporal queimada. Em queimaduras, '
    'a extensão da área queimada costuma ser estimada por métodos como a regra '
    'dos nove, diagramas corporais e critérios clínicos específicos, e depois '
    'comparada à ASC total quando necessário.';

class BodySurfaceAreaStep {
  const BodySurfaceAreaStep({required this.label, required this.value});

  final String label;
  final String value;
}

class BodySurfaceAreaResult {
  const BodySurfaceAreaResult({
    required this.weightKg,
    required this.heightCm,
    required this.product,
    required this.dividedBy3600,
    required this.bsaM2,
    required this.steps,
  });

  final double weightKg;
  final double heightCm;
  final double product;
  final double dividedBy3600;
  final double bsaM2;
  final List<BodySurfaceAreaStep> steps;

  String get bsaFormatted => bsaM2.toStringAsFixed(2);
}

double? parseHeightCmOnly(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return value;
}

BodySurfaceAreaResult calculateBodySurfaceAreaMosteller({
  required double weightKg,
  required double heightCm,
}) {
  if (weightKg <= 0 || weightKg > 500) {
    throw ArgumentError('Peso deve ser maior que zero e menor que 500 kg.');
  }
  if (heightCm < 30 || heightCm > 250) {
    throw ArgumentError('Altura deve estar entre 30 cm e 250 cm.');
  }

  final product = heightCm * weightKg;
  final divided = product / mostellerDivisor;
  final bsa = math.sqrt(divided);
  final rounded = double.parse(bsa.toStringAsFixed(2));

  final heightDisplay = heightCm == heightCm.roundToDouble()
      ? heightCm.toInt().toString()
      : heightCm.toStringAsFixed(1);
  final weightDisplay = weightKg == weightKg.roundToDouble()
      ? weightKg.toInt().toString()
      : weightKg.toStringAsFixed(1);

  final steps = buildMostellerExplanationSteps(
    heightCm: heightCm,
    weightKg: weightKg,
    heightDisplay: heightDisplay,
    weightDisplay: weightDisplay,
    product: product,
    divided: divided,
    bsa: rounded,
  );

  return BodySurfaceAreaResult(
    weightKg: weightKg,
    heightCm: heightCm,
    product: product,
    dividedBy3600: divided,
    bsaM2: rounded,
    steps: steps,
  );
}

List<BodySurfaceAreaStep> buildMostellerExplanationSteps({
  required double heightCm,
  required double weightKg,
  required String heightDisplay,
  required String weightDisplay,
  required double product,
  required double divided,
  required double bsa,
}) {
  return [
    BodySurfaceAreaStep(
      label: 'Altura',
      value: '$heightDisplay cm',
    ),
    BodySurfaceAreaStep(
      label: 'Peso',
      value: '$weightDisplay kg',
    ),
    BodySurfaceAreaStep(
      label: '$heightDisplay × $weightDisplay',
      value: _formatNumber(product),
    ),
    BodySurfaceAreaStep(
      label: '${_formatNumber(product)} ÷ $mostellerDivisor',
      value: _formatNumber(divided, decimals: 4),
    ),
    BodySurfaceAreaStep(
      label: '√${_formatNumber(divided, decimals: 4)}',
      value: '${bsa.toStringAsFixed(2).replaceAll('.', ',')} m²',
    ),
  ];
}

String _formatNumber(double value, {int decimals = 0}) {
  if (decimals == 0 && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  final text = value.toStringAsFixed(decimals);
  return text.replaceAll('.', ',');
}

const List<String> bsaClinicalUses = [
  'Cálculo de dose de alguns medicamentos, especialmente em oncologia '
      '(ex.: quimioterápicos indexados por m²).',
  'Avaliação clínica e acompanhamento em pediatria.',
  'Ajuste de alguns parâmetros fisiológicos e fórmulas que usam superfície corporal.',
  'Contexto de queimaduras: comparar a ASC total com a área corporal acometida '
      '(a extensão queimada usa outros métodos, não esta calculadora isoladamente).',
];

const List<String> bsaHowToCalculateBullets = [
  'Multiplique a altura em centímetros pelo peso em quilogramas.',
  'Divida o resultado por 3600.',
  'Calcule a raiz quadrada do valor obtido.',
  'O resultado final é a área de superfície corporal em metros quadrados (m²).',
];
