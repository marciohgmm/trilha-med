import 'package:flutter/material.dart';

import '../../domain/medical_tools/weight_dose.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';

class WeightDoseCalculatorPage extends StatefulWidget {
  const WeightDoseCalculatorPage({super.key});

  @override
  State<WeightDoseCalculatorPage> createState() =>
      _WeightDoseCalculatorPageState();
}

class _WeightDoseCalculatorPageState extends State<WeightDoseCalculatorPage> {
  final _weightCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  WeightDoseResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items = await _historyStore.loadForTool(MedicalToolIds.weightDose);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _calculate() async {
    final weight = parseMedicalDouble(_weightCtrl.text);
    final dose = parseMedicalDouble(_doseCtrl.text);

    if (weight == null || dose == null) {
      setState(() {
        _error = 'Informe peso e dose válidos.';
        _result = null;
      });
      return;
    }

    try {
      final result = calculateWeightDose(
        weightKg: weight,
        dosePerKgMg: dose,
      );
      setState(() {
        _result = result;
        _error = null;
      });

      await _historyStore.append(
        MedicalToolHistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          toolId: MedicalToolIds.weightDose,
          title: 'Dose por peso',
          summary:
              '${result.totalDoseMg.toStringAsFixed(0)} mg (${result.formulaText})',
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
    _weightCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Text('Dose por peso'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Calcule a dose total com base no peso do paciente.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            MedicalNumericField(
              controller: _weightCtrl,
              label: 'Peso do paciente',
              suffix: 'kg',
            ),
            const SizedBox(height: 14),
            MedicalNumericField(
              controller: _doseCtrl,
              label: 'Dose prescrita',
              suffix: 'mg/kg',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular dose',
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
                title: 'Dose total',
                value: '${_result!.totalDoseMg.toStringAsFixed(2)} mg',
                details: [
                  'Cálculo detalhado:',
                  _result!.formulaText,
                  'Peso: ${_result!.weightKg.toStringAsFixed(1)} kg',
                  'Dose: ${_result!.dosePerKgMg.toStringAsFixed(2)} mg/kg',
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
