import 'package:flutter/material.dart';

import '../../domain/medical_tools/cockcroft_gault.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';

class CockcroftGaultCalculatorPage extends StatefulWidget {
  const CockcroftGaultCalculatorPage({super.key});

  @override
  State<CockcroftGaultCalculatorPage> createState() =>
      _CockcroftGaultCalculatorPageState();
}

class _CockcroftGaultCalculatorPageState
    extends State<CockcroftGaultCalculatorPage> {
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _creatinineCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  CockcroftSex _sex = CockcroftSex.male;
  CockcroftGaultResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items =
        await _historyStore.loadForTool(MedicalToolIds.cockcroftGault);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _calculate() async {
    final age = parseMedicalInt(_ageCtrl.text);
    final weight = parseMedicalDouble(_weightCtrl.text);
    final creatinine = parseMedicalDouble(_creatinineCtrl.text);

    if (age == null || weight == null || creatinine == null) {
      setState(() {
        _error = 'Preencha idade, peso e creatinina válidos.';
        _result = null;
      });
      return;
    }

    try {
      final result = calculateCockcroftGault(
        ageYears: age,
        weightKg: weight,
        creatinineMgDl: creatinine,
        sex: _sex,
      );
      setState(() {
        _result = result;
        _error = null;
      });

      final sexLabel =
          _sex == CockcroftSex.male ? 'Masculino' : 'Feminino';
      await _historyStore.append(
        MedicalToolHistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          toolId: MedicalToolIds.cockcroftGault,
          title: 'Cockcroft-Gault',
          summary:
              'ClCr ${result.clearanceMlMin} mL/min — $sexLabel, ${result.ageYears}a',
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
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _creatinineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Text('Clearance de Creatinina'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cockcroft-Gault — estimativa de clearance (creatinina em mg/dL).',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            MedicalNumericField(
              controller: _ageCtrl,
              label: 'Idade',
              suffix: 'anos',
              allowDecimal: false,
            ),
            const SizedBox(height: 14),
            MedicalNumericField(
              controller: _weightCtrl,
              label: 'Peso',
              suffix: 'kg',
            ),
            const SizedBox(height: 14),
            MedicalNumericField(
              controller: _creatinineCtrl,
              label: 'Creatinina sérica',
              suffix: 'mg/dL',
            ),
            const SizedBox(height: 14),
            SegmentedButton<CockcroftSex>(
              segments: const [
                ButtonSegment(
                  value: CockcroftSex.male,
                  label: Text('Masculino'),
                ),
                ButtonSegment(
                  value: CockcroftSex.female,
                  label: Text('Feminino'),
                ),
              ],
              selected: {_sex},
              onSelectionChanged: (s) {
                setState(() => _sex = s.first);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular clearance',
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
              MedicalResultCard(
                title: 'Clearance estimado',
                value: '${_result!.clearanceMlMin} mL/min',
                subtitle: _result!.interpretation,
                details: [
                  if (_result!.sex == CockcroftSex.male)
                    'Fórmula: (140 − idade) × peso ÷ (72 × creatinina)'
                  else
                    'Fórmula: [(140 − idade) × peso ÷ (72 × creatinina)] × 0,85',
                  'Idade: ${_result!.ageYears} anos',
                  'Peso: ${_result!.weightKg} kg',
                  'Creatinina: ${_result!.creatinineMgDl} mg/dL',
                ],
              ),
            ],
            MedicalHistorySection(entries: _history),
          ],
        ),
      ),
    );
  }
}
