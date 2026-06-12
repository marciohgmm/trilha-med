import 'package:flutter/material.dart';

import '../../domain/medical_tools/adult_bmi.dart';
import '../../domain/medical_tools/pediatric_bmi.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';
import '../../widgets/medical_tools/pediatric_bmi_study_widgets.dart';

class PediatricBmiCalculatorPage extends StatefulWidget {
  const PediatricBmiCalculatorPage({super.key});

  @override
  State<PediatricBmiCalculatorPage> createState() =>
      _PediatricBmiCalculatorPageState();
}

class _PediatricBmiCalculatorPageState extends State<PediatricBmiCalculatorPage> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageYearsCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  PediatricBiologicalSex _sex = PediatricBiologicalSex.male;
  PediatricBmiResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    for (final c in [
      _weightCtrl,
      _heightCtrl,
      _ageYearsCtrl,
      _ageMonthsCtrl,
    ]) {
      c.addListener(_onInputsChanged);
    }
  }

  void _onInputsChanged() {
    final empty = _weightCtrl.text.trim().isEmpty &&
        _heightCtrl.text.trim().isEmpty &&
        _ageYearsCtrl.text.trim().isEmpty &&
        _ageMonthsCtrl.text.trim().isEmpty;
    if (empty && (_result != null || _error != null)) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _loadHistory() async {
    final items = await _historyStore.loadForTool(MedicalToolIds.pediatricBmi);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _calculate() async {
    final weight = parseMedicalDouble(_weightCtrl.text);
    final heightCm = parseAdultHeightToCm(_heightCtrl.text);
    final ageMonths = parsePediatricAgeMonths(
      yearsText: _ageYearsCtrl.text,
      monthsText: _ageMonthsCtrl.text,
    );

    if (weight == null || heightCm == null || ageMonths == null) {
      setState(() {
        _error =
            'Informe peso (kg), altura (cm ou m), idade em anos e, se necessário, '
            'meses adicionais (0–11).';
        _result = null;
      });
      return;
    }

    try {
      final result = calculatePediatricBmi(
        weightKg: weight,
        heightCm: heightCm,
        ageMonths: ageMonths,
        sex: _sex,
      );
      setState(() {
        _result = result;
        _error = null;
      });

      final classification = result.hasPercentileClassification
          ? result.classificationLabel!
          : 'IMC sem classificação por percentil (< 2 anos)';
      await _historyStore.append(
        MedicalToolHistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          toolId: MedicalToolIds.pediatricBmi,
          title: 'IMC Pediátrico',
          summary:
              'IMC ${result.bmi.toStringAsFixed(1)} — $classification '
              '(${result.ageLabel}, ${pediatricBmiSexLabel(result.sex)})',
          calculatedAt: DateTime.now(),
        ),
      );
      await _loadHistory();
    } on ArgumentError catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _weightCtrl,
      _heightCtrl,
      _ageYearsCtrl,
      _ageMonthsCtrl,
    ]) {
      c.removeListener(_onInputsChanged);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Text('IMC Pediátrico'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ferramenta de estudo — IMC com percentil por idade e sexo (2 a 19 anos)',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const PediatricBmiDisclaimerBox(text: pediatricBmiAgeSexDisclaimer),
            const SizedBox(height: 12),
            const PediatricBmiDisclaimerBox(
              text: pediatricBmiEducationalDisclaimer,
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: 20),
            MedicalNumericField(
              controller: _weightCtrl,
              label: 'Peso',
              suffix: 'kg',
              hint: 'Ex.: 32',
            ),
            const SizedBox(height: 14),
            MedicalNumericField(
              controller: _heightCtrl,
              label: 'Altura',
              suffix: 'cm ou m',
              hint: 'Ex.: 140 ou 1,40',
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Altura em centímetros (140) ou metros (1,40).',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: MedicalNumericField(
                    controller: _ageYearsCtrl,
                    label: 'Idade',
                    suffix: 'anos',
                    hint: 'Ex.: 10',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MedicalNumericField(
                    controller: _ageMonthsCtrl,
                    label: 'Meses',
                    suffix: '0–11',
                    hint: '0',
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Faixa principal: 2 a 19 anos. Meses adicionais são opcionais (0–11).',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sexo biológico',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PediatricBiologicalSex>(
              segments: const [
                ButtonSegment(
                  value: PediatricBiologicalSex.male,
                  label: Text('Masculino'),
                  icon: Icon(Icons.male, size: 18),
                ),
                ButtonSegment(
                  value: PediatricBiologicalSex.female,
                  label: Text('Feminino'),
                  icon: Icon(Icons.female, size: 18),
                ),
              ],
              selected: {_sex},
              onSelectionChanged: (selected) {
                setState(() => _sex = selected.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return MedicalToolsTheme.primary;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return MedicalToolsTheme.primary;
                  }
                  return Colors.white;
                }),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular IMC pediátrico',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              if (_result!.isUnderAgeTwo) ...[
                PediatricBmiWarningCard(message: pediatricBmiUnderTwoWarning),
                const SizedBox(height: 14),
              ],
              PediatricBmiResultCard(result: _result!),
              const SizedBox(height: 14),
              PediatricBmiInterpretationCard(result: _result!),
              const SizedBox(height: 14),
              PediatricBmiReferenceTableCard(
                activeCategory: _result!.category,
              ),
              const SizedBox(height: 14),
              const PediatricBmiGrowthCurvesNoteCard(),
              if (_result!.guide != null) ...[
                const SizedBox(height: 14),
                PediatricBmiEducationCard(result: _result!),
              ],
              const SizedBox(height: 14),
              PediatricBmiStudyCard(
                title: 'Observações importantes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      pediatricBmiAgeSexDisclaimer,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      pediatricBmiEducationalDisclaimer,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (_result!.hasPercentileClassification) ...[
                      const SizedBox(height: 12),
                      const Text(
                        pediatricBmiPercentileDisclaimer,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              const PediatricBmiReferenceTableCard(),
            ],
            MedicalHistorySection(entries: _history),
          ],
        ),
      ),
    );
  }
}
