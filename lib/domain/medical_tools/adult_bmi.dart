/// IMC adulto — classificação OMS.
class AdultBmiResult {
  const AdultBmiResult({
    required this.bmi,
    required this.classification,
    required this.weightKg,
    required this.heightCm,
  });

  final double bmi;
  final String classification;
  final double weightKg;
  final double heightCm;

  double get heightM => heightCm / 100;
}

String classifyAdultBmi(double bmi) {
  if (bmi < 18.5) return 'Baixo peso';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Sobrepeso';
  if (bmi < 35) return 'Obesidade I';
  if (bmi < 40) return 'Obesidade II';
  return 'Obesidade III';
}

AdultBmiResult calculateAdultBmi({
  required double weightKg,
  required double heightCm,
}) {
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (heightCm <= 0) {
    throw ArgumentError('Altura deve ser maior que zero.');
  }

  final heightM = heightCm / 100;
  final bmi = weightKg / (heightM * heightM);
  final rounded = double.parse(bmi.toStringAsFixed(1));

  return AdultBmiResult(
    bmi: rounded,
    classification: classifyAdultBmi(rounded),
    weightKg: weightKg,
    heightCm: heightCm,
  );
}
