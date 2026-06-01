enum CockcroftSex { male, female }

/// Clearance de creatinina — Cockcroft-Gault (creatinina em mg/dL).
class CockcroftGaultResult {
  const CockcroftGaultResult({
    required this.clearanceMlMin,
    required this.interpretation,
    required this.ageYears,
    required this.weightKg,
    required this.creatinineMgDl,
    required this.sex,
  });

  final double clearanceMlMin;
  final String interpretation;
  final int ageYears;
  final double weightKg;
  final double creatinineMgDl;
  final CockcroftSex sex;
}

String interpretCockcroftClearance(double clCr) {
  if (clCr >= 90) {
    return 'Função renal normal ou levemente reduzida (≥ 90 mL/min).';
  }
  if (clCr >= 60) {
    return 'Redução leve (60–89 mL/min).';
  }
  if (clCr >= 30) {
    return 'Redução moderada (30–59 mL/min).';
  }
  if (clCr >= 15) {
    return 'Redução grave (15–29 mL/min).';
  }
  return 'Falência renal (< 15 mL/min).';
}

CockcroftGaultResult calculateCockcroftGault({
  required int ageYears,
  required double weightKg,
  required double creatinineMgDl,
  required CockcroftSex sex,
}) {
  if (ageYears <= 0 || ageYears > 120) {
    throw ArgumentError('Idade inválida.');
  }
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (creatinineMgDl <= 0) {
    throw ArgumentError('Creatinina deve ser maior que zero.');
  }

  var clCr = (140 - ageYears) * weightKg / (72 * creatinineMgDl);
  if (sex == CockcroftSex.female) {
    clCr *= 0.85;
  }
  final rounded = double.parse(clCr.toStringAsFixed(1));

  return CockcroftGaultResult(
    clearanceMlMin: rounded,
    interpretation: interpretCockcroftClearance(rounded),
    ageYears: ageYears,
    weightKg: weightKg,
    creatinineMgDl: creatinineMgDl,
    sex: sex,
  );
}
