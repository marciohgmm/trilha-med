import 'pediatric_bmi.dart';

/// Valores de IMC (kg/m²) nos percentis CDC 2000 — marcos anuais (2–19 anos).
/// Interpolação linear entre meses; ver [pediatricBmiPercentileDisclaimer].
class CdcBmiPercentileAnchor {
  const CdcBmiPercentileAnchor({
    required this.ageMonths,
    required this.p5,
    required this.p50,
    required this.p85,
    required this.p95,
  });

  final int ageMonths;
  final double p5;
  final double p50;
  final double p85;
  final double p95;
}

/// Meninos — percentis suavizados CDC (referência educacional).
const List<CdcBmiPercentileAnchor> _maleAnchors = [
  CdcBmiPercentileAnchor(ageMonths: 24, p5: 14.5, p50: 16.1, p85: 17.6, p95: 18.3),
  CdcBmiPercentileAnchor(ageMonths: 36, p5: 14.0, p50: 15.4, p85: 16.9, p95: 17.8),
  CdcBmiPercentileAnchor(ageMonths: 48, p5: 13.8, p50: 15.2, p85: 16.7, p95: 17.7),
  CdcBmiPercentileAnchor(ageMonths: 60, p5: 13.6, p50: 15.2, p85: 16.9, p95: 18.0),
  CdcBmiPercentileAnchor(ageMonths: 72, p5: 13.5, p50: 15.3, p85: 17.1, p95: 18.4),
  CdcBmiPercentileAnchor(ageMonths: 84, p5: 13.5, p50: 15.5, p85: 17.5, p95: 19.0),
  CdcBmiPercentileAnchor(ageMonths: 96, p5: 13.6, p50: 15.7, p85: 17.9, p95: 19.6),
  CdcBmiPercentileAnchor(ageMonths: 108, p5: 13.8, p50: 16.0, p85: 18.4, p95: 20.3),
  CdcBmiPercentileAnchor(ageMonths: 120, p5: 14.0, p50: 16.4, p85: 19.1, p95: 21.1),
  CdcBmiPercentileAnchor(ageMonths: 132, p5: 14.3, p50: 16.9, p85: 19.9, p95: 22.0),
  CdcBmiPercentileAnchor(ageMonths: 144, p5: 14.7, p50: 17.5, p85: 20.7, p95: 23.1),
  CdcBmiPercentileAnchor(ageMonths: 156, p5: 15.2, p50: 18.2, p85: 21.7, p95: 24.2),
  CdcBmiPercentileAnchor(ageMonths: 168, p5: 15.8, p50: 19.0, p85: 22.6, p95: 25.3),
  CdcBmiPercentileAnchor(ageMonths: 180, p5: 16.4, p50: 19.8, p85: 23.5, p95: 26.4),
  CdcBmiPercentileAnchor(ageMonths: 192, p5: 17.0, p50: 20.7, p85: 24.5, p95: 27.5),
  CdcBmiPercentileAnchor(ageMonths: 204, p5: 17.6, p50: 21.5, p85: 25.4, p95: 28.5),
  CdcBmiPercentileAnchor(ageMonths: 216, p5: 18.1, p50: 22.2, p85: 26.2, p95: 29.3),
  CdcBmiPercentileAnchor(ageMonths: 228, p5: 18.6, p50: 22.8, p85: 26.9, p95: 30.0),
];

/// Meninas — percentis suavizados CDC (referência educacional).
const List<CdcBmiPercentileAnchor> _femaleAnchors = [
  CdcBmiPercentileAnchor(ageMonths: 24, p5: 14.3, p50: 15.8, p85: 17.2, p95: 18.0),
  CdcBmiPercentileAnchor(ageMonths: 36, p5: 13.9, p50: 15.2, p85: 16.6, p95: 17.5),
  CdcBmiPercentileAnchor(ageMonths: 48, p5: 13.7, p50: 15.0, p85: 16.5, p95: 17.5),
  CdcBmiPercentileAnchor(ageMonths: 60, p5: 13.5, p50: 14.9, p85: 16.6, p95: 17.7),
  CdcBmiPercentileAnchor(ageMonths: 72, p5: 13.4, p50: 15.0, p85: 16.8, p95: 18.0),
  CdcBmiPercentileAnchor(ageMonths: 84, p5: 13.4, p50: 15.2, p85: 17.2, p95: 18.5),
  CdcBmiPercentileAnchor(ageMonths: 96, p5: 13.5, p50: 15.5, p85: 17.7, p95: 19.2),
  CdcBmiPercentileAnchor(ageMonths: 108, p5: 13.7, p50: 15.9, p85: 18.3, p95: 20.0),
  CdcBmiPercentileAnchor(ageMonths: 120, p5: 13.9, p50: 16.4, p85: 19.0, p95: 21.0),
  CdcBmiPercentileAnchor(ageMonths: 132, p5: 14.2, p50: 17.0, p85: 19.9, p95: 22.2),
  CdcBmiPercentileAnchor(ageMonths: 144, p5: 14.6, p50: 17.7, p85: 20.9, p95: 23.4),
  CdcBmiPercentileAnchor(ageMonths: 156, p5: 15.1, p50: 18.5, p85: 22.0, p95: 24.7),
  CdcBmiPercentileAnchor(ageMonths: 168, p5: 15.7, p50: 19.3, p85: 23.0, p95: 25.9),
  CdcBmiPercentileAnchor(ageMonths: 180, p5: 16.3, p50: 20.1, p85: 24.0, p95: 27.0),
  CdcBmiPercentileAnchor(ageMonths: 192, p5: 16.9, p50: 20.9, p85: 25.0, p95: 28.1),
  CdcBmiPercentileAnchor(ageMonths: 204, p5: 17.4, p50: 21.6, p85: 25.8, p95: 29.0),
  CdcBmiPercentileAnchor(ageMonths: 216, p5: 17.9, p50: 22.2, p85: 26.5, p95: 29.8),
  CdcBmiPercentileAnchor(ageMonths: 228, p5: 18.3, p50: 22.7, p85: 27.1, p95: 30.4),
];

List<CdcBmiPercentileAnchor> cdcAnchorsFor(PediatricBiologicalSex sex) {
  return sex == PediatricBiologicalSex.male ? _maleAnchors : _femaleAnchors;
}

CdcBmiPercentileAnchor interpolateCdcAnchors(
  PediatricBiologicalSex sex,
  int ageMonths,
) {
  final anchors = cdcAnchorsFor(sex);
  if (ageMonths <= anchors.first.ageMonths) return anchors.first;
  if (ageMonths >= anchors.last.ageMonths) return anchors.last;

  for (var i = 0; i < anchors.length - 1; i++) {
    final a = anchors[i];
    final b = anchors[i + 1];
    if (ageMonths >= a.ageMonths && ageMonths <= b.ageMonths) {
      final t = (ageMonths - a.ageMonths) / (b.ageMonths - a.ageMonths);
      return CdcBmiPercentileAnchor(
        ageMonths: ageMonths,
        p5: _lerp(a.p5, b.p5, t),
        p50: _lerp(a.p50, b.p50, t),
        p85: _lerp(a.p85, b.p85, t),
        p95: _lerp(a.p95, b.p95, t),
      );
    }
  }
  return anchors.last;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Estima percentil por interpolação entre P5, P50, P85 e P95 (referência CDC).
double estimateBmiPercentileFromAnchors(double bmi, CdcBmiPercentileAnchor anchor) {
  if (bmi <= anchor.p5) {
    return (5 * (bmi / anchor.p5)).clamp(0.5, 5.0);
  }
  if (bmi <= anchor.p50) {
    return 5 + 45 * (bmi - anchor.p5) / (anchor.p50 - anchor.p5);
  }
  if (bmi <= anchor.p85) {
    return 50 + 35 * (bmi - anchor.p50) / (anchor.p85 - anchor.p50);
  }
  if (bmi <= anchor.p95) {
    return 85 + 10 * (bmi - anchor.p85) / (anchor.p95 - anchor.p85);
  }
  final excess = (bmi - anchor.p95) / anchor.p95;
  return (95 + excess * 40).clamp(95, 99.9);
}

PediatricBmiCategory classifyPediatricBmiFromPercentile(
  double estimatedPercentile, {
  required double bmi,
  required double p95,
}) {
  final severeByBmi = bmi >= 35;
  final severeByP95 = bmi >= p95 * 1.2;
  if (severeByBmi || severeByP95) {
    return PediatricBmiCategory.severeObesity;
  }
  if (estimatedPercentile < 5) return PediatricBmiCategory.underweight;
  if (estimatedPercentile < 85) return PediatricBmiCategory.eutrophic;
  if (estimatedPercentile < 95) return PediatricBmiCategory.overweight;
  return PediatricBmiCategory.obesity;
}
