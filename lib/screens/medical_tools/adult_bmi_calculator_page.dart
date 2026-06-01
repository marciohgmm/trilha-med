import 'package:flutter/material.dart';

import '../../domain/medical_tools/adult_bmi.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';

class AdultBmiCalculatorPage extends StatefulWidget {
  const AdultBmiCalculatorPage({super.key});

  @override
  State<AdultBmiCalculatorPage> createState() => _AdultBmiCalculatorPageState();
}

class _AdultBmiCalculatorPageState extends State<AdultBmiCalculatorPage> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  AdultBmiResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items = await _historyStore.loadForTool(MedicalToolIds.adultBmi);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _calculate() async {
    final weight = parseMedicalDouble(_weightCtrl.text);
    final height = parseMedicalDouble(_heightCtrl.text);

    if (weight == null || height == null) {
      setState(() {
        _error = 'Informe peso e altura válidos.';
        _result = null;
      });
      return;
    }

    try {
      final result = calculateAdultBmi(weightKg: weight, heightCm: height);
      setState(() {
        _result = result;
        _error = null;
      });

      await _historyStore.append(
        MedicalToolHistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          toolId: MedicalToolIds.adultBmi,
          title: 'IMC Adulto',
          summary:
              'IMC ${result.bmi.toStringAsFixed(1)} — ${result.classification} '
              '(${result.weightKg} kg, ${result.heightCm} cm)',
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
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Text('IMC Adulto'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Índice de Massa Corporal (OMS)',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            MedicalNumericField(
              controller: _weightCtrl,
              label: 'Peso',
              suffix: 'kg',
            ),
            const SizedBox(height: 14),
            MedicalNumericField(
              controller: _heightCtrl,
              label: 'Altura',
              suffix: 'cm',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular IMC',
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
                title: 'IMC calculado',
                value: _result!.bmi.toStringAsFixed(1),
                subtitle: _result!.classification,
                details: [
                  'Fórmula: peso ÷ altura²',
                  '${_result!.weightKg} kg ÷ (${_result!.heightM.toStringAsFixed(2)} m)²',
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
