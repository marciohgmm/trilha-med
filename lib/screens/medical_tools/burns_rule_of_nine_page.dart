import 'package:flutter/material.dart';

import '../../domain/medical_tools/burns_rule_of_nine.dart';
import '../../widgets/medical_tools/burns_body_diagram.dart';
import '../../services/medical_tools/burns_tbsa_transfer.dart';
import '../../widgets/medical_tools/burns_study_widgets.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';
import 'parkland_calculator_page.dart';

class BurnsRuleOfNinePage extends StatefulWidget {
  const BurnsRuleOfNinePage({
    super.key,
    this.returnPercentToParkland = false,
  });

  /// Quando true, exibe ação para devolver o % SCQ à Regra de Parkland.
  final bool returnPercentToParkland;

  @override
  State<BurnsRuleOfNinePage> createState() => _BurnsRuleOfNinePageState();
}

class _BurnsRuleOfNinePageState extends State<BurnsRuleOfNinePage> {
  BurnsRuleOfNineSelection _selection = const BurnsRuleOfNineSelection();
  BurnRegionId? _lastTappedId;
  bool _showExample = false;

  void _onRegionTapped(BurnRegionId id) {
    if (!canAddRegion(_selection, id) && !_selection.isSelected(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A soma não pode ultrapassar 100%. Desmarque uma região para adicionar outra.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selection = _selection.toggle(id);
      _lastTappedId = id;
    });
  }

  void _clearAll() {
    setState(() {
      _selection = _selection.clear();
      _lastTappedId = null;
      _showExample = false;
    });
  }

  void _applyExample() {
    setState(() {
      _selection = _selection.applyExample();
      _lastTappedId = BurnRegionId.headAnterior;
      _showExample = true;
    });
  }

  void _sendPercentToParkland() {
    final percent = _selection.totalPercent;
    if (percent <= 0) return;
    BurnsTbsaTransfer.setPercent(percent);
    if (widget.returnPercentToParkland) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParklandCalculatorPage(initialTbsaPercent: percent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastRegion =
        _lastTappedId != null ? burnRegionById(_lastTappedId!) : null;
    final percent = _selection.totalPercent;

    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: Text(
          widget.returnPercentToParkland
              ? 'Selecionar % SCQ'
              : 'Queimaduras – Regra dos 9',
        ),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: widget.returnPercentToParkland && percent > 0
          ? FloatingActionButton.extended(
              onPressed: _sendPercentToParkland,
              backgroundColor: const Color(0xFFDC2626),
              icon: const Icon(Icons.check),
              label: Text('Usar ${formatBurnPercent(percent)} no Parkland'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Superfície Corporal Queimada',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Adulto — toque nas regiões acometidas (frente e costas)',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            BurnsTotalCard(totalPercent: _selection.totalPercent),
            if (lastRegion != null) ...[
              const SizedBox(height: 12),
              BurnsLastTappedCard(region: lastRegion),
            ],
            const SizedBox(height: 20),
            BurnsStudyCard(
              title: 'Selecione as áreas queimadas',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 400;
                  if (narrow) {
                    return Column(
                      children: [
                        BurnsBodyDiagram(
                          title: 'Vista anterior (frente)',
                          side: BurnBodySide.anterior,
                          layouts: anteriorBurnLayouts,
                          selection: _selection,
                          highlightId: _lastTappedId,
                          onRegionTapped: _onRegionTapped,
                        ),
                        const SizedBox(height: 24),
                        BurnsBodyDiagram(
                          title: 'Vista posterior (costas)',
                          side: BurnBodySide.posterior,
                          layouts: posteriorBurnLayouts,
                          selection: _selection,
                          highlightId: _lastTappedId,
                          onRegionTapped: _onRegionTapped,
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: BurnsBodyDiagram(
                          title: 'Vista anterior (frente)',
                          side: BurnBodySide.anterior,
                          layouts: anteriorBurnLayouts,
                          selection: _selection,
                          highlightId: _lastTappedId,
                          onRegionTapped: _onRegionTapped,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BurnsBodyDiagram(
                          title: 'Vista posterior (costas)',
                          side: BurnBodySide.posterior,
                          layouts: posteriorBurnLayouts,
                          selection: _selection,
                          highlightId: _lastTappedId,
                          onRegionTapped: _onRegionTapped,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (!widget.returnPercentToParkland && percent > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendPercentToParkland,
                  icon: const Icon(Icons.water_drop_outlined),
                  label: Text(
                    'Abrir Regra de Parkland (${formatBurnPercent(percent)} SCQ)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selection.isEmpty ? null : _clearAll,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Limpar seleção'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MedicalToolsTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _applyExample,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Exemplo de soma'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BurnsSelectedListCard(selection: _selection),
            const SizedBox(height: 14),
            BurnsExampleSumCard(visible: _showExample),
            const SizedBox(height: 14),
            const BurnsHowItWorksCard(),
            const SizedBox(height: 14),
            const BurnsDisclaimerBox(text: burnsEducationalDisclaimer),
            const SizedBox(height: 10),
            const BurnsDisclaimerBox(
              text: burnsPediatricMethodNote,
              icon: Icons.child_care_outlined,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
