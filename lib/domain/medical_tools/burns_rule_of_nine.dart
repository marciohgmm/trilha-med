// Regra dos 9 — adulto (estimativa educativa de superfície corporal queimada).

/// Lado do corpo no diagrama.
enum BurnBodySide { anterior, posterior }

/// Regiões anatômicas selecionáveis (adulto).
enum BurnRegionId {
  headAnterior,
  headPosterior,
  rightArmAnterior,
  rightArmPosterior,
  leftArmAnterior,
  leftArmPosterior,
  chestAnterior,
  abdomenAnterior,
  upperBackPosterior,
  lowerBackPosterior,
  rightLegAnterior,
  rightLegPosterior,
  leftLegAnterior,
  leftLegPosterior,
  perineum,
}

class BurnRegionDefinition {
  const BurnRegionDefinition({
    required this.id,
    required this.displayName,
    required this.percent,
    required this.side,
  });

  final BurnRegionId id;
  final String displayName;

  /// Percentual desta região isolada (soma de todas = 100%).
  final double percent;
  final BurnBodySide side;
}

const List<BurnRegionDefinition> adultBurnRegions = [
  BurnRegionDefinition(
    id: BurnRegionId.headAnterior,
    displayName: 'Cabeça e pescoço (anterior)',
    percent: 4.5,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.headPosterior,
    displayName: 'Cabeça e pescoço (posterior)',
    percent: 4.5,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.rightArmAnterior,
    displayName: 'Braço direito (anterior)',
    percent: 4.5,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.rightArmPosterior,
    displayName: 'Braço direito (posterior)',
    percent: 4.5,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.leftArmAnterior,
    displayName: 'Braço esquerdo (anterior)',
    percent: 4.5,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.leftArmPosterior,
    displayName: 'Braço esquerdo (posterior)',
    percent: 4.5,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.chestAnterior,
    displayName: 'Tórax anterior',
    percent: 9,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.abdomenAnterior,
    displayName: 'Abdome anterior',
    percent: 9,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.upperBackPosterior,
    displayName: 'Dorso superior',
    percent: 9,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.lowerBackPosterior,
    displayName: 'Dorso inferior / lombar',
    percent: 9,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.rightLegAnterior,
    displayName: 'Perna direita (anterior)',
    percent: 9,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.rightLegPosterior,
    displayName: 'Perna direita (posterior)',
    percent: 9,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.leftLegAnterior,
    displayName: 'Perna esquerda (anterior)',
    percent: 9,
    side: BurnBodySide.anterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.leftLegPosterior,
    displayName: 'Perna esquerda (posterior)',
    percent: 9,
    side: BurnBodySide.posterior,
  ),
  BurnRegionDefinition(
    id: BurnRegionId.perineum,
    displayName: 'Períneo',
    percent: 1,
    side: BurnBodySide.anterior,
  ),
];

final Map<BurnRegionId, BurnRegionDefinition> _regionById = {
  for (final r in adultBurnRegions) r.id: r,
};

BurnRegionDefinition burnRegionById(BurnRegionId id) => _regionById[id]!;

List<BurnRegionDefinition> burnRegionsForSide(BurnBodySide side) =>
    adultBurnRegions.where((r) => r.side == side).toList();

String formatBurnPercent(double value) {
  final text = value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')}%';
}

const String burnsRuleOfNineIntro =
    'A regra dos 9 é um método rápido para estimar a porcentagem da superfície '
    'corporal queimada em adultos. Cada grande região corporal recebe um valor '
    'percentual, e a soma das áreas acometidas fornece a estimativa total.';

const String burnsAdultScopeNote =
    'Esta ferramenta é voltada ao adulto.';

const String burnsPediatricNote =
    'Em crianças, a avaliação mais adequada é a tabela de Lund-Browder.';

const String burnsPalmNote =
    'Áreas pequenas e espalhadas também podem ser estimadas pela palma da mão '
    'do próprio paciente, equivalente a cerca de 1%.';

const String burnsEducationalDisclaimer =
    'Esta ferramenta tem finalidade educativa e de apoio ao raciocínio clínico. '
    'Não substitui avaliação especializada.';

const String burnsPediatricMethodNote =
    'A regra dos 9 é uma estimativa rápida. Em pediatria, a proporção corporal '
    'é diferente e o método de Lund-Browder é mais apropriado.';

/// Retângulo normalizado (0–1) para desenho e toque.
class BurnRegionLayout {
  const BurnRegionLayout({
    required this.id,
    required this.rect,
  });

  final BurnRegionId id;
  final BurnRegionRect rect;
}

class BurnRegionRect {
  const BurnRegionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Layouts relativos do boneco (frente e costas).
const List<BurnRegionLayout> anteriorBurnLayouts = [
  BurnRegionLayout(
    id: BurnRegionId.headAnterior,
    rect: BurnRegionRect(left: 0.34, top: 0.02, width: 0.32, height: 0.11),
  ),
  BurnRegionLayout(
    id: BurnRegionId.chestAnterior,
    rect: BurnRegionRect(left: 0.30, top: 0.14, width: 0.40, height: 0.13),
  ),
  BurnRegionLayout(
    id: BurnRegionId.abdomenAnterior,
    rect: BurnRegionRect(left: 0.30, top: 0.28, width: 0.40, height: 0.13),
  ),
  BurnRegionLayout(
    id: BurnRegionId.leftArmAnterior,
    rect: BurnRegionRect(left: 0.06, top: 0.14, width: 0.20, height: 0.30),
  ),
  BurnRegionLayout(
    id: BurnRegionId.rightArmAnterior,
    rect: BurnRegionRect(left: 0.74, top: 0.14, width: 0.20, height: 0.30),
  ),
  BurnRegionLayout(
    id: BurnRegionId.leftLegAnterior,
    rect: BurnRegionRect(left: 0.26, top: 0.44, width: 0.22, height: 0.40),
  ),
  BurnRegionLayout(
    id: BurnRegionId.rightLegAnterior,
    rect: BurnRegionRect(left: 0.52, top: 0.44, width: 0.22, height: 0.40),
  ),
  BurnRegionLayout(
    id: BurnRegionId.perineum,
    rect: BurnRegionRect(left: 0.40, top: 0.54, width: 0.20, height: 0.06),
  ),
];

const List<BurnRegionLayout> posteriorBurnLayouts = [
  BurnRegionLayout(
    id: BurnRegionId.headPosterior,
    rect: BurnRegionRect(left: 0.34, top: 0.02, width: 0.32, height: 0.11),
  ),
  BurnRegionLayout(
    id: BurnRegionId.upperBackPosterior,
    rect: BurnRegionRect(left: 0.30, top: 0.14, width: 0.40, height: 0.13),
  ),
  BurnRegionLayout(
    id: BurnRegionId.lowerBackPosterior,
    rect: BurnRegionRect(left: 0.30, top: 0.28, width: 0.40, height: 0.13),
  ),
  BurnRegionLayout(
    id: BurnRegionId.leftArmPosterior,
    rect: BurnRegionRect(left: 0.06, top: 0.14, width: 0.20, height: 0.30),
  ),
  BurnRegionLayout(
    id: BurnRegionId.rightArmPosterior,
    rect: BurnRegionRect(left: 0.74, top: 0.14, width: 0.20, height: 0.30),
  ),
  BurnRegionLayout(
    id: BurnRegionId.leftLegPosterior,
    rect: BurnRegionRect(left: 0.26, top: 0.44, width: 0.22, height: 0.40),
  ),
  BurnRegionLayout(
    id: BurnRegionId.rightLegPosterior,
    rect: BurnRegionRect(left: 0.52, top: 0.44, width: 0.22, height: 0.40),
  ),
];

/// Exemplo didático solicitado (total 18%).
const List<BurnRegionId> burnsExampleRegionIds = [
  BurnRegionId.headAnterior,
  BurnRegionId.leftArmAnterior,
  BurnRegionId.rightLegAnterior,
];

class BurnsRuleOfNineSelection {
  const BurnsRuleOfNineSelection([this._selected = const {}]);

  final Set<BurnRegionId> _selected;

  Set<BurnRegionId> get selected => Set.unmodifiable(_selected);

  bool isSelected(BurnRegionId id) => _selected.contains(id);

  double get totalPercent {
    var sum = 0.0;
    for (final id in _selected) {
      sum += burnRegionById(id).percent;
    }
    return sum.clamp(0, 100);
  }

  List<BurnRegionDefinition> get selectedRegions {
    final list = _selected.map(burnRegionById).toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return list;
  }

  bool get isEmpty => _selected.isEmpty;

  BurnsRuleOfNineSelection toggle(BurnRegionId id) {
    final next = Set<BurnRegionId>.from(_selected);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      final added = burnRegionById(id).percent;
      final current = totalPercent;
      if (current + added > 100.0001) {
        return this;
      }
      next.add(id);
    }
    return BurnsRuleOfNineSelection(next);
  }

  BurnsRuleOfNineSelection clear() => const BurnsRuleOfNineSelection();

  BurnsRuleOfNineSelection applyExample() =>
      BurnsRuleOfNineSelection(Set.from(burnsExampleRegionIds));
}

/// Mensagem quando não é possível adicionar (total > 100%).
bool canAddRegion(BurnsRuleOfNineSelection selection, BurnRegionId id) {
  if (selection.isSelected(id)) return true;
  return selection.totalPercent + burnRegionById(id).percent <= 100.0001;
}

List<String> buildExampleSumLines() {
  final lines = <String>[];
  var total = 0.0;
  for (final id in burnsExampleRegionIds) {
    final r = burnRegionById(id);
    lines.add('${r.displayName} = ${formatBurnPercent(r.percent)}');
    total += r.percent;
  }
  lines.add('Total = ${formatBurnPercent(total)}');
  return lines;
}
