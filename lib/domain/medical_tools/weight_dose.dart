/// Dose total por peso (mg/kg).
class WeightDoseResult {
  const WeightDoseResult({
    required this.weightKg,
    required this.dosePerKgMg,
    required this.totalDoseMg,
  });

  final double weightKg;
  final double dosePerKgMg;
  final double totalDoseMg;

  String get formulaText =>
      '${weightKg.toStringAsFixed(1)} kg × ${dosePerKgMg.toStringAsFixed(2)} mg/kg '
      '= ${totalDoseMg.toStringAsFixed(2)} mg';
}

WeightDoseResult calculateWeightDose({
  required double weightKg,
  required double dosePerKgMg,
}) {
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (dosePerKgMg <= 0) {
    throw ArgumentError('Dose por kg deve ser maior que zero.');
  }

  final total = weightKg * dosePerKgMg;
  return WeightDoseResult(
    weightKg: weightKg,
    dosePerKgMg: dosePerKgMg,
    totalDoseMg: double.parse(total.toStringAsFixed(2)),
  );
}
