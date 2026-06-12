// Regra de Parkland — estimativa educativa de reposição volêmica inicial.

/// mL/kg/% SCQ
const double parklandMultiplier = 4;

const Duration parklandFirstPhaseDuration = Duration(hours: 8);
const Duration parklandTotalDuration = Duration(hours: 24);

const String parklandIntroDisclaimer =
    'A Regra de Parkland é uma estimativa inicial de reposição volêmica em queimaduras.';

const String parklandClinicalAdjustmentDisclaimer =
    'A reposição deve ser ajustada conforme resposta clínica, perfusão e débito urinário.';

const String parklandBurnTimeDisclaimer =
    'O cálculo considera a hora da queimadura, não a hora em que o paciente chegou ao atendimento.';

const String parklandSuperficialBurnDisclaimer =
    'Queimaduras superficiais sem repercussão importante não entram da mesma forma no '
    'raciocínio de grande queimado.';

const String parklandEducationalToolDisclaimer =
    'Esta ferramenta tem finalidade educativa e não substitui avaliação especializada.';

const String parklandCrystalloidNote =
    'A fórmula clássica costuma usar cristalóide — tradicionalmente Ringer Lactato — '
    'como referência de reposição inicial nas primeiras 24 horas.';

const String parklandBeyond24hMessage =
    'Já se passaram mais de 24 horas desde a queimadura. A Regra de Parkland não se '
    'aplica mais como cálculo de reposição inicial; a conduta deve seguir reavaliação '
    'clínica e protocolos vigentes.';

enum ParklandTimelineStatus {
  /// 0 a < 8 h desde a queimadura.
  withinFirst8Hours,

  /// 8 h a < 24 h — fase das 16 horas.
  withinSecondPhase,

  /// ≥ 24 h.
  beyond24Hours,
}

class ParklandVolumeBreakdown {
  const ParklandVolumeBreakdown({
    required this.total24hMl,
    required this.first8hMl,
    required this.next16hMl,
  });

  final double total24hMl;
  final double first8hMl;
  final double next16hMl;
}

class ParklandPhasePlan {
  const ParklandPhasePlan({
    required this.targetMl,
    required this.remainingMl,
    required this.hoursRemaining,
    required this.rateMlPerHour,
  });

  final double targetMl;
  final double remainingMl;
  final double hoursRemaining;
  final double rateMlPerHour;
}

class ParklandCalculationResult {
  const ParklandCalculationResult({
    required this.weightKg,
    required this.tbsaPercent,
    required this.burnDateTime,
    required this.referenceDateTime,
    required this.volumes,
    required this.elapsed,
    required this.status,
    required this.fluidAlreadyGivenMl,
    required this.totalRemainingMl,
    required this.firstPhasePlan,
    required this.secondPhasePlan,
    required this.explanationSteps,
    required this.warnings,
  });

  final double weightKg;
  final double tbsaPercent;
  final DateTime burnDateTime;
  final DateTime referenceDateTime;
  final ParklandVolumeBreakdown volumes;
  final Duration elapsed;
  final ParklandTimelineStatus status;
  final double fluidAlreadyGivenMl;
  final double totalRemainingMl;
  final ParklandPhasePlan firstPhasePlan;
  final ParklandPhasePlan secondPhasePlan;
  final List<String> explanationSteps;
  final List<String> warnings;

  bool get isBeyond24Hours => status == ParklandTimelineStatus.beyond24Hours;

  double? get currentRateMlPerHour {
    switch (status) {
      case ParklandTimelineStatus.withinFirst8Hours:
        return firstPhasePlan.rateMlPerHour > 0
            ? firstPhasePlan.rateMlPerHour
            : null;
      case ParklandTimelineStatus.withinSecondPhase:
        return secondPhasePlan.rateMlPerHour > 0
            ? secondPhasePlan.rateMlPerHour
            : null;
      case ParklandTimelineStatus.beyond24Hours:
        return null;
    }
  }

  Duration get first8hWindowRemaining {
    final left = parklandFirstPhaseDuration - elapsed;
    if (left.isNegative) return Duration.zero;
    return left;
  }
}

/// Volume total 24h = 4 × peso × %SCQ.
double calculateParklandTotal24hMl({
  required double weightKg,
  required double tbsaPercent,
}) {
  return parklandMultiplier * weightKg * tbsaPercent;
}

ParklandVolumeBreakdown calculateParklandVolumeBreakdown({
  required double weightKg,
  required double tbsaPercent,
}) {
  final total = calculateParklandTotal24hMl(
    weightKg: weightKg,
    tbsaPercent: tbsaPercent,
  );
  final half = total / 2;
  return ParklandVolumeBreakdown(
    total24hMl: total,
    first8hMl: half,
    next16hMl: half,
  );
}

Duration elapsedSinceBurn({
  required DateTime burnDateTime,
  required DateTime referenceDateTime,
}) {
  final burn = burnDateTime;
  final ref = referenceDateTime;
  if (!ref.isAfter(burn)) return Duration.zero;
  return ref.difference(burn);
}

ParklandTimelineStatus parklandTimelineStatus(Duration elapsed) {
  if (elapsed >= parklandTotalDuration) {
    return ParklandTimelineStatus.beyond24Hours;
  }
  if (elapsed >= parklandFirstPhaseDuration) {
    return ParklandTimelineStatus.withinSecondPhase;
  }
  return ParklandTimelineStatus.withinFirst8Hours;
}

ParklandPhasePlan _phasePlan({
  required double phaseTargetMl,
  required double fluidAlreadyGivenMl,
  required double phaseAlreadyCoveredMl,
  required double hoursRemaining,
}) {
  final remaining =
      (phaseTargetMl - phaseAlreadyCoveredMl).clamp(0.0, double.infinity).toDouble();
  final rate =
      hoursRemaining > 0 ? remaining / hoursRemaining : 0.0;
  return ParklandPhasePlan(
    targetMl: phaseTargetMl,
    remainingMl: remaining,
    hoursRemaining: hoursRemaining,
    rateMlPerHour: rate,
  );
}

ParklandCalculationResult calculateParklandResuscitation({
  required double weightKg,
  required double tbsaPercent,
  required DateTime burnDateTime,
  DateTime? referenceDateTime,
  double fluidAlreadyGivenMl = 0,
}) {
  if (weightKg <= 0) {
    throw ArgumentError('Peso deve ser maior que zero.');
  }
  if (tbsaPercent <= 0 || tbsaPercent > 100) {
    throw ArgumentError('% SCQ deve estar entre 0 e 100 (exclua 0).');
  }
  if (fluidAlreadyGivenMl < 0) {
    throw ArgumentError('Volume já infundido não pode ser negativo.');
  }

  final ref = referenceDateTime ?? DateTime.now();
  if (ref.isBefore(burnDateTime)) {
    throw ArgumentError('A hora atual não pode ser anterior à hora da queimadura.');
  }

  final volumes = calculateParklandVolumeBreakdown(
    weightKg: weightKg,
    tbsaPercent: tbsaPercent,
  );
  final elapsed = elapsedSinceBurn(
    burnDateTime: burnDateTime,
    referenceDateTime: ref,
  );
  final status = parklandTimelineStatus(elapsed);

  final totalRemaining = (volumes.total24hMl - fluidAlreadyGivenMl)
      .clamp(0, volumes.total24hMl)
      .toDouble();

  final givenToPhase1 =
      fluidAlreadyGivenMl.clamp(0.0, volumes.first8hMl).toDouble();
  final givenBeyondPhase1 = (fluidAlreadyGivenMl - volumes.first8hMl)
      .clamp(0.0, double.infinity)
      .toDouble();

  final first8hHoursLeft =
      ((parklandFirstPhaseDuration.inMinutes - elapsed.inMinutes) / 60.0)
          .clamp(0.0, 8.0)
          .toDouble();
  final secondHoursLeft = status == ParklandTimelineStatus.withinSecondPhase
      ? ((parklandTotalDuration.inMinutes - elapsed.inMinutes) / 60.0)
          .clamp(0.0, 16.0)
          .toDouble()
      : 0.0;

  final firstPhasePlan = _phasePlan(
    phaseTargetMl: volumes.first8hMl,
    fluidAlreadyGivenMl: fluidAlreadyGivenMl,
    phaseAlreadyCoveredMl: givenToPhase1,
    hoursRemaining: status == ParklandTimelineStatus.withinFirst8Hours
        ? first8hHoursLeft
        : 0,
  );

  final secondPhasePlan = _phasePlan(
    phaseTargetMl: volumes.next16hMl,
    fluidAlreadyGivenMl: fluidAlreadyGivenMl,
    phaseAlreadyCoveredMl: givenBeyondPhase1,
    hoursRemaining: status == ParklandTimelineStatus.withinSecondPhase
        ? secondHoursLeft
        : 0,
  );

  final warnings = <String>[];
  if (fluidAlreadyGivenMl > volumes.total24hMl) {
    warnings.add(
      'Volume já infundido (${formatParklandVolumeMl(fluidAlreadyGivenMl)}) '
      'supera o total estimado de 24h. Restante zerado — reavalie clinicamente.',
    );
  }
  if (status == ParklandTimelineStatus.withinFirst8Hours &&
      firstPhasePlan.remainingMl > 0 &&
      first8hHoursLeft <= 0) {
    warnings.add('A janela de 8 horas iniciais está encerrada pelo tempo.');
  }

  final steps = buildParklandExplanationSteps(
    weightKg: weightKg,
    tbsaPercent: tbsaPercent,
    volumes: volumes,
    elapsed: elapsed,
    status: status,
    fluidAlreadyGivenMl: fluidAlreadyGivenMl,
    totalRemainingMl: totalRemaining,
    firstPhasePlan: firstPhasePlan,
    secondPhasePlan: secondPhasePlan,
  );

  return ParklandCalculationResult(
    weightKg: weightKg,
    tbsaPercent: tbsaPercent,
    burnDateTime: burnDateTime,
    referenceDateTime: ref,
    volumes: volumes,
    elapsed: elapsed,
    status: status,
    fluidAlreadyGivenMl: fluidAlreadyGivenMl,
    totalRemainingMl: totalRemaining,
    firstPhasePlan: firstPhasePlan,
    secondPhasePlan: secondPhasePlan,
    explanationSteps: steps,
    warnings: warnings,
  );
}

List<String> buildParklandExplanationSteps({
  required double weightKg,
  required double tbsaPercent,
  required ParklandVolumeBreakdown volumes,
  required Duration elapsed,
  required ParklandTimelineStatus status,
  required double fluidAlreadyGivenMl,
  required double totalRemainingMl,
  required ParklandPhasePlan firstPhasePlan,
  required ParklandPhasePlan secondPhasePlan,
}) {
  final w = _formatNum(weightKg);
  final p = _formatNum(tbsaPercent);
  final steps = <String>[
    'Volume total 24h = $parklandMultiplier mL × $w kg × $p% SCQ = '
        '${formatParklandVolumeMl(volumes.total24hMl)}.',
    'Primeiras 8 h (desde a queimadura): 50% → '
        '${formatParklandVolumeMl(volumes.first8hMl)}.',
    'Próximas 16 h: 50% → ${formatParklandVolumeMl(volumes.next16hMl)}.',
    'Tempo desde a queimadura: ${formatParklandDuration(elapsed)}.',
  ];

  if (fluidAlreadyGivenMl > 0) {
    steps.add(
      'Volume já infundido: ${formatParklandVolumeMl(fluidAlreadyGivenMl)}. '
      'Restante total estimado: ${formatParklandVolumeMl(totalRemainingMl)}.',
    );
  }

  switch (status) {
    case ParklandTimelineStatus.withinFirst8Hours:
      steps.add(
        'Fase atual: primeiras 8 h. Restante nesta fase: '
        '${formatParklandVolumeMl(firstPhasePlan.remainingMl)} em '
        '${_formatHours(firstPhasePlan.hoursRemaining)} → '
        '${formatParklandRate(firstPhasePlan.rateMlPerHour)}.',
      );
    case ParklandTimelineStatus.withinSecondPhase:
      steps.add(
        'A janela inicial de 8 h já passou. Fase atual: 16 h seguintes. '
        'Restante nesta fase: ${formatParklandVolumeMl(secondPhasePlan.remainingMl)} em '
        '${_formatHours(secondPhasePlan.hoursRemaining)} → '
        '${formatParklandRate(secondPhasePlan.rateMlPerHour)}.',
      );
    case ParklandTimelineStatus.beyond24Hours:
      steps.add(parklandBeyond24hMessage);
  }

  return steps;
}

List<String> buildParklandDidacticExampleLines() {
  return const [
    'Exemplo didático:',
    'Peso = 70 kg · SCQ = 20%',
    'Total = 4 × 70 × 20 = 5600 mL',
    'Primeiras 8 h = 2800 mL',
    'Próximas 16 h = 2800 mL',
  ];
}

String formatParklandVolumeMl(double ml) {
  return '${ml.round()} mL';
}

String formatParklandRate(double mlPerHour) {
  if (mlPerHour <= 0) return '—';
  return '${mlPerHour.round()} mL/h';
}

String formatParklandDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes min';
}

String formatParklandDateTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} $h:$m';
}

String parklandStatusLabel(ParklandTimelineStatus status) {
  switch (status) {
    case ParklandTimelineStatus.withinFirst8Hours:
      return 'Dentro da janela inicial de 8 horas';
    case ParklandTimelineStatus.withinSecondPhase:
      return 'Fase das 16 horas seguintes (8–24 h)';
    case ParklandTimelineStatus.beyond24Hours:
      return 'Mais de 24 horas desde a queimadura';
  }
}

String _formatNum(double v) {
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

String _formatHours(double hours) {
  if (hours <= 0) return '0 h';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (m == 0) return '$h h';
  return '$h h $m min';
}
