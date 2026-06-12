import 'package:flutter/material.dart';

import '../../domain/medical_tools/body_surface_area.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/body_surface_area_study_widgets.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';

class BodySurfaceAreaCalculatorPage extends StatefulWidget {
  const BodySurfaceAreaCalculatorPage({super.key});

  @override
  State<BodySurfaceAreaCalculatorPage> createState() =>
      _BodySurfaceAreaCalculatorPageState();
}

class _BodySurfaceAreaCalculatorPageState
    extends State<BodySurfaceAreaCalculatorPage> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  BodySurfaceAreaResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _weightCtrl.addListener(_onInputsChanged);
    _heightCtrl.addListener(_onInputsChanged);
  }

  void _onInputsChanged() {
    final empty =
        _weightCtrl.text.trim().isEmpty && _heightCtrl.text.trim().isEmpty;
    if (empty && (_result != null || _error != null)) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _loadHistory() async {
    final items =
        await _historyStore.loadForTool(MedicalToolIds.bodySurfaceArea);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _calculate() async {
    final weight = parseMedicalDouble(_weightCtrl.text);
    final heightCm = parseHeightCmOnly(_heightCtrl.text);

    if (weight == null || heightCm == null) {
      setState(() {
        _error = 'Informe peso (kg) e altura (cm) válidos.';
        _result = null;
      });
      return;
    }

    try {
      final result = calculateBodySurfaceAreaMosteller(
        weightKg: weight,
        heightCm: heightCm,
      );
      setState(() {
        _result = result;
        _error = null;
      });

      await _historyStore.append(
        MedicalToolHistoryEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          toolId: MedicalToolIds.bodySurfaceArea,
          title: 'Superfície Corporal (ASC)',
          summary:
              'ASC ${result.bsaFormatted} m² — '
              '${result.weightKg} kg, ${result.heightCm.toStringAsFixed(0)} cm',
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
    _weightCtrl.removeListener(_onInputsChanged);
    _heightCtrl.removeListener(_onInputsChanged);
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Superfície Corporal (ASC)',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Área de Superfície Corporal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fórmula de Mosteller — ferramenta de estudo',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            const BsaDisclaimerBox(),
            const SizedBox(height: 20),
            BsaStudyCard(
              title: 'Dados do paciente',
              child: Column(
                children: [
                  MedicalNumericField(
                    controller: _weightCtrl,
                    label: 'Peso',
                    suffix: 'kg',
                    hint: 'Ex.: 70',
                  ),
                  const SizedBox(height: 14),
                  MedicalNumericField(
                    controller: _heightCtrl,
                    label: 'Altura',
                    suffix: 'cm',
                    hint: 'Ex.: 170',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular ASC',
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
              BsaResultCard(result: _result!),
              const SizedBox(height: 14),
              BsaWorkedExampleCard(result: _result!),
            ],
            const SizedBox(height: 20),
            const BsaFormulaCard(),
            const SizedBox(height: 14),
            const BsaHowToCard(),
            const SizedBox(height: 14),
            const BsaClinicalUsesCard(),
            const SizedBox(height: 14),
            const BsaImportantNoteCard(),
            const SizedBox(height: 14),
            const BsaDisclaimerBox(),
            MedicalHistorySection(entries: _history),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
