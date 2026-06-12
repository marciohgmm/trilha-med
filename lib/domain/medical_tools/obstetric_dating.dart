// Cálculo educativo de DPP e idade gestacional (DUM e ultrassom).

/// Duração obstétrica padrão (40 semanas).
const int obstetricGestationDays = 280;

/// Ciclo menstrual de referência para a regra de Naegele.
const int defaultMenstrualCycleDays = 28;

const String obstetricDppEducationalDisclaimer =
    'A data provável do parto é uma estimativa. Deve ser interpretada junto com '
    'a história clínica, a DUM confiável e os exames obstétricos.';

const String obstetricFirstTrimesterUsDisclaimer =
    'O ultrassom do primeiro trimestre é o método mais preciso para datar a gestação.';

const String obstetricStudyToolDisclaimer =
    'Esta ferramenta tem finalidade educativa e de apoio ao raciocínio clínico, '
    'não substituindo avaliação profissional.';

const String obstetricSuboptimalDatingNote =
    'Observação educativa: gestação sem confirmação adequada da data antes de '
    '22 semanas pode ser considerada datação subótima/subdatada na prática '
    'obstétrica — reforça a importância do ultrassom precoce quando disponível.';

enum ObstetricDatingMethod { lmp, ultrasound }

enum UltrasoundTrimester {
  first,
  second,
}

class GestationalAge {
  const GestationalAge({required this.totalDays});

  final int totalDays;

  int get weeks => totalDays ~/ 7;
  int get days => totalDays % 7;

  bool get isAtOrBeyondTerm => totalDays >= obstetricGestationDays;

  bool get isSuboptimalDatingThreshold =>
      totalDays >= 154; // 22 semanas
}

/// Resultado do cálculo pela DUM.
class DueDateByLmpResult {
  const DueDateByLmpResult({
    required this.lmp,
    required this.cycleLengthDays,
    required this.dueDate,
    required this.gestationalAgeToday,
    required this.referenceDate,
    required this.cycleAdjustmentDays,
    required this.explanationSteps,
  });

  final DateTime lmp;
  final int cycleLengthDays;
  final DateTime dueDate;
  final GestationalAge gestationalAgeToday;
  final DateTime referenceDate;
  final int cycleAdjustmentDays;
  final List<String> explanationSteps;

  String get methodLabel => 'DPP por DUM (regra de Naegele)';
}

/// Resultado do cálculo por ultrassom.
class DueDateByUltrasoundResult {
  const DueDateByUltrasoundResult({
    required this.ultrasoundDate,
    required this.trimester,
    required this.gestationalAgeAtExam,
    required this.dueDate,
    required this.gestationalAgeToday,
    required this.referenceDate,
    required this.explanationSteps,
  });

  final DateTime ultrasoundDate;
  final UltrasoundTrimester trimester;
  final GestationalAge gestationalAgeAtExam;
  final DateTime dueDate;
  final GestationalAge gestationalAgeToday;
  final DateTime referenceDate;
  final List<String> explanationSteps;

  String get methodLabel {
    return trimester == UltrasoundTrimester.first
        ? 'DPP por ultrassom do 1º trimestre'
        : 'DPP por ultrassom do 2º trimestre';
  }

  String get trimesterLabel => trimester == UltrasoundTrimester.first
      ? '1º trimestre'
      : '2º trimestre';
}

class DumUltrasoundComparison {
  const DumUltrasoundComparison({
    required this.lmpResult,
    required this.ultrasoundResult,
    required this.differenceDays,
    required this.observation,
  });

  final DueDateByLmpResult lmpResult;
  final DueDateByUltrasoundResult ultrasoundResult;

  /// DPP ultrassom − DPP DUM (positivo = ultrassom projeta parto mais tarde).
  final int differenceDays;
  final String observation;
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

String formatObstetricDate(DateTime date) {
  final d = dateOnly(date);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

String formatGestationalAge(GestationalAge age) {
  if (age.totalDays < 0) return '—';
  if (age.days == 0) {
    return '${age.weeks} semana${age.weeks == 1 ? '' : 's'}';
  }
  return '${age.weeks} semana${age.weeks == 1 ? '' : 's'} e '
      '${age.days} dia${age.days == 1 ? '' : 's'}';
}

String formatGestationalAgeFromDays(int totalDays) =>
    formatGestationalAge(GestationalAge(totalDays: totalDays));

int? parseGestationalWeeks(String text) {
  final v = int.tryParse(text.trim());
  if (v == null || v < 0 || v > 45) return null;
  return v;
}

int? parseGestationalExtraDays(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final v = int.tryParse(trimmed);
  if (v == null || v < 0 || v > 6) return null;
  return v;
}

int gestationalDaysFromWeeksAndDays(int weeks, int extraDays) {
  if (weeks < 0 || weeks > 45) {
    throw ArgumentError('Semanas gestacionais inválidas.');
  }
  if (extraDays < 0 || extraDays > 6) {
    throw ArgumentError('Dias adicionais devem estar entre 0 e 6.');
  }
  return weeks * 7 + extraDays;
}

GestationalAge gestationalAgeOnDate({
  required DateTime startOfGestation,
  required DateTime onDate,
}) {
  final days = daysBetween(startOfGestation, onDate);
  return GestationalAge(totalDays: days);
}

/// DPP = DUM + 280 dias + ajuste de ciclo (ciclo − 28).
DueDateByLmpResult calculateDueDateByLmp({
  required DateTime lmp,
  int cycleLengthDays = defaultMenstrualCycleDays,
  DateTime? referenceDate,
}) {
  if (cycleLengthDays < 21 || cycleLengthDays > 45) {
    throw ArgumentError('Duração do ciclo deve estar entre 21 e 45 dias.');
  }

  final ref = dateOnly(referenceDate ?? DateTime.now());
  final lmpDate = dateOnly(lmp);

  if (lmpDate.isAfter(ref)) {
    throw ArgumentError('A DUM não pode ser posterior à data de referência.');
  }

  final cycleAdjustment = cycleLengthDays - defaultMenstrualCycleDays;
  final dueDate = lmpDate.add(
    Duration(days: obstetricGestationDays + cycleAdjustment),
  );

  final gaToday = gestationalAgeOnDate(
    startOfGestation: lmpDate,
    onDate: ref,
  );

  final steps = <String>[
    'DUM informada: ${formatObstetricDate(lmpDate)}.',
    'Base obstétrica: gestação de $obstetricGestationDays dias (40 semanas).',
    'DPP = DUM + $obstetricGestationDays dias → ${formatObstetricDate(dueDate.subtract(Duration(days: cycleAdjustment)))}'
        '${cycleAdjustment != 0 ? ' (antes do ajuste de ciclo)' : ''}.',
    'Regra de Naegele: somar 7 dias à DUM e voltar 3 meses '
        '(equivalente a DUM + 280 dias para ciclo de 28 dias).',
  ];

  if (cycleAdjustment != 0) {
    steps.add(
      'Ciclo de $cycleLengthDays dias (≠ 28): ajuste de '
      '${cycleAdjustment > 0 ? '+' : ''}$cycleAdjustment dia(s) na DPP → '
      '${formatObstetricDate(dueDate)}.',
    );
  } else {
    steps.add('Ciclo de 28 dias: sem ajuste adicional.');
  }

  steps.add(
    'Idade gestacional hoje (${formatObstetricDate(ref)}): '
    '${formatGestationalAge(gaToday)} '
    '(${gaToday.totalDays} dias desde a DUM).',
  );

  return DueDateByLmpResult(
    lmp: lmpDate,
    cycleLengthDays: cycleLengthDays,
    dueDate: dueDate,
    gestationalAgeToday: gaToday,
    referenceDate: ref,
    cycleAdjustmentDays: cycleAdjustment,
    explanationSteps: steps,
  );
}

/// DPP = data do US + (280 − idade gestacional no dia do exame).
DueDateByUltrasoundResult calculateDueDateByUltrasound({
  required DateTime ultrasoundDate,
  required int gestationalWeeksAtExam,
  required int gestationalExtraDaysAtExam,
  required UltrasoundTrimester trimester,
  DateTime? referenceDate,
}) {
  final ref = dateOnly(referenceDate ?? DateTime.now());
  final usDate = dateOnly(ultrasoundDate);

  if (usDate.isAfter(ref)) {
    throw ArgumentError(
      'A data do ultrassom não pode ser posterior à data de referência.',
    );
  }

  final gaAtExamDays = gestationalDaysFromWeeksAndDays(
    gestationalWeeksAtExam,
    gestationalExtraDaysAtExam,
  );

  if (gaAtExamDays > obstetricGestationDays) {
    throw ArgumentError(
      'Idade gestacional no exame não pode exceder 40 semanas ($obstetricGestationDays dias).',
    );
  }

  final daysRemaining = obstetricGestationDays - gaAtExamDays;
  final dueDate = usDate.add(Duration(days: daysRemaining));

  final impliedLmp = usDate.subtract(Duration(days: gaAtExamDays));
  final gaToday = gestationalAgeOnDate(
    startOfGestation: impliedLmp,
    onDate: ref,
  );

  final trimesterLabel = trimester == UltrasoundTrimester.first
      ? '1º trimestre (maior precisão para datar)'
      : '2º trimestre (útil, porém em geral menos preciso que o do 1º)';

  final steps = <String>[
    'Data do ultrassom: ${formatObstetricDate(usDate)}.',
    'Idade gestacional no exame: '
        '${formatGestationalAgeFromDays(gaAtExamDays)} ($gaAtExamDays dias).',
    'Tipo informado: $trimesterLabel.',
    'Dias restantes até 40 semanas no dia do exame: '
        '$obstetricGestationDays − $gaAtExamDays = $daysRemaining dias.',
    'DPP = data do ultrassom + $daysRemaining dias → '
        '${formatObstetricDate(dueDate)}.',
    'Idade gestacional hoje (${formatObstetricDate(ref)}): '
        '${formatGestationalAge(gaToday)}.',
  ];

  return DueDateByUltrasoundResult(
    ultrasoundDate: usDate,
    trimester: trimester,
    gestationalAgeAtExam: GestationalAge(totalDays: gaAtExamDays),
    dueDate: dueDate,
    gestationalAgeToday: gaToday,
    referenceDate: ref,
    explanationSteps: steps,
  );
}

DumUltrasoundComparison? compareDumAndUltrasound({
  DueDateByLmpResult? lmpResult,
  DueDateByUltrasoundResult? ultrasoundResult,
}) {
  if (lmpResult == null || ultrasoundResult == null) return null;

  final diff = daysBetween(lmpResult.dueDate, ultrasoundResult.dueDate);

  String observation;
  if (diff == 0) {
    observation =
        'As duas estimativas coincidem na mesma DPP. Mesmo assim, avalie a '
        'confiabilidade da DUM e a qualidade do ultrassom precoce no contexto clínico.';
  } else if (diff.abs() <= 5) {
    observation =
        'Diferença pequena ($diff dia${diff.abs() == 1 ? '' : 's'}). Em divergências, '
        'o ultrassom do 1º trimestre costuma prevalecer quando bem realizado; '
        'discuta com a equipe obstétrica.';
  } else {
    observation =
        'Diferença de ${diff.abs()} dias entre os métodos. O ultrassom do 1º '
        'trimestre tende a ser mais preciso para datar; a DUM depende de memória '
        'da data e de ciclos regulares. Priorize avaliação obstétrica integrada.';
  }

  return DumUltrasoundComparison(
    lmpResult: lmpResult,
    ultrasoundResult: ultrasoundResult,
    differenceDays: diff,
    observation: observation,
  );
}

String ultrasoundTrimesterEducationalNote(UltrasoundTrimester trimester) {
  switch (trimester) {
    case UltrasoundTrimester.first:
      return 'No 1º trimestre, a medida do comprimento cabeça-nádega (CCN) é o '
          'padrão mais usado para datar com maior precisão.';
    case UltrasoundTrimester.second:
      return 'No 2º trimestre, biometrias como biparietal e femur ajudam na '
          'estimativa, mas erros de datação tendem a ser maiores que no 1º trimestre.';
  }
}

/// Conteúdo fixo da seção "Como aprender essa conta".
const List<ObstetricStudyTopic> obstetricStudyTopics = [
  ObstetricStudyTopic(
    title: '1. Conceito de idade gestacional',
    body:
        'Conta-se em semanas e dias a partir do primeiro dia da última menstruação '
        '(DUM), assumindo gestação de 40 semanas (280 dias). É uma convenção '
        'obstétrica — não é a idade desde a concepção.',
  ),
  ObstetricStudyTopic(
    title: '2. Cálculo por DUM',
    body:
        'DPP ≈ DUM + 280 dias. Forma prática: regra de Naegele (somar 7 dias e '
        'voltar 3 meses). Ciclos diferentes de 28 dias podem exigir ajuste em dias.',
  ),
  ObstetricStudyTopic(
    title: '3. Cálculo por ultrassom',
    body:
        'Com a idade gestacional no dia do exame, projetam-se os dias que faltam '
        'para 40 semanas: DPP = data do US + (280 − idade gestacional em dias no exame).',
  ),
  ObstetricStudyTopic(
    title: '4. Quando o US do 1º trimestre é mais confiável',
    body:
        'Entre cerca de 8 e 13+6 semanas, o CCN permite datar com menor erro. '
        'É o método preferido quando há dúvida sobre a DUM.',
  ),
  ObstetricStudyTopic(
    title: '5. DPP é estimativa',
    body:
        'Apenas uma minoria nasce exatamente na DPP. Parto entre 37 e 42 semanas '
        'é considerado termo; a DPP orienta seguimento, não define o dia do parto.',
  ),
];

class ObstetricStudyTopic {
  const ObstetricStudyTopic({required this.title, required this.body});

  final String title;
  final String body;
}

const String obstetricLmpDidacticText =
    'Pela DUM, a data provável do parto é estimada somando 280 dias ao primeiro '
    'dia da última menstruação. Uma forma prática de fazer isso é usar a regra de '
    'Naegele: somar 7 dias à DUM e voltar 3 meses. Se o ciclo menstrual não tiver '
    '28 dias, pode ser necessário ajustar alguns dias.';

const String obstetricUltrasoundDidacticText =
    'No ultrassom, a idade gestacional informada no dia do exame permite projetar '
    'a DPP: faltam (280 − idade gestacional em dias) para completar 40 semanas. '
    'O ultrassom do 1º trimestre é mais preciso para datar; o do 2º trimestre '
    'também ajuda, mas costuma ser menos preciso que o do 1º.';
