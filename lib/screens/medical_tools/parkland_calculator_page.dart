import 'package:flutter/material.dart';

import '../../domain/medical_tools/parkland_rule.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/burns_tbsa_transfer.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';
import '../../widgets/medical_tools/parkland_study_widgets.dart';
import 'burns_rule_of_nine_page.dart';

class ParklandCalculatorPage extends StatefulWidget {
  const ParklandCalculatorPage({
    super.key,
    this.initialTbsaPercent,
  });

  final double? initialTbsaPercent;

  @override
  State<ParklandCalculatorPage> createState() => _ParklandCalculatorPageState();
}

class _ParklandCalculatorPageState extends State<ParklandCalculatorPage> {
  final _weightCtrl = TextEditingController();
  final _tbsaCtrl = TextEditingController();
  final _fluidGivenCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  DateTime? _burnDateTime;
  ParklandCalculationResult? _result;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _applyImportedTbsa();
    for (final c in [_weightCtrl, _tbsaCtrl, _fluidGivenCtrl]) {
      c.addListener(_onInputsChanged);
    }
  }

  void _applyImportedTbsa() {
    final imported =
        BurnsTbsaTransfer.consumePercent() ?? widget.initialTbsaPercent;
    if (imported != null && imported > 0) {
      _tbsaCtrl.text = imported == imported.roundToDouble()
          ? imported.toInt().toString()
          : imported.toStringAsFixed(1);
    }
  }

  void _onInputsChanged() {
    final empty = _weightCtrl.text.trim().isEmpty &&
        _tbsaCtrl.text.trim().isEmpty &&
        _fluidGivenCtrl.text.trim().isEmpty &&
        _burnDateTime == null;
    if (empty && (_result != null || _error != null)) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _loadHistory() async {
    final items = await _historyStore.loadForTool(MedicalToolIds.parklandRule);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _pickBurnDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _burnDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 3)),
      lastDate: now,
      helpText: 'Data da queimadura',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_burnDateTime ?? now),
      helpText: 'Hora da queimadura',
    );
    if (time == null || !mounted) return;

    setState(() {
      _burnDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _importTbsaFromRuleOfNine() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BurnsRuleOfNinePage(returnPercentToParkland: true),
      ),
    );
    final percent = BurnsTbsaTransfer.consumePercent();
    if (percent != null && percent > 0 && mounted) {
      setState(() {
        _tbsaCtrl.text = percent == percent.roundToDouble()
            ? percent.toInt().toString()
            : percent.toStringAsFixed(1);
      });
    }
  }

  void _calculate() {
    final weight = parseMedicalDouble(_weightCtrl.text);
    final tbsa = parseMedicalDouble(_tbsaCtrl.text);
    final fluidGiven = parseMedicalDouble(_fluidGivenCtrl.text) ?? 0;

    if (weight == null || tbsa == null || _burnDateTime == null) {
      setState(() {
        _error = 'Informe peso (kg), % SCQ e data/hora da queimadura.';
        _result = null;
      });
      return;
    }

    try {
      final result = calculateParklandResuscitation(
        weightKg: weight,
        tbsaPercent: tbsa,
        burnDateTime: _burnDateTime!,
        fluidAlreadyGivenMl: fluidGiven,
      );
      setState(() {
        _result = result;
        _error = null;
      });

      if (!result.isBeyond24Hours) {
        final rate = result.currentRateMlPerHour;
        _historyStore.append(
          MedicalToolHistoryEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            toolId: MedicalToolIds.parklandRule,
            title: 'Regra de Parkland',
            summary:
                '${formatParklandVolumeMl(result.volumes.total24hMl)} / 24h — '
                'SCQ ${tbsa.toStringAsFixed(0)}% · '
                '${rate != null ? formatParklandRate(rate) : "fora da janela"}',
            calculatedAt: DateTime.now(),
          ),
        ).then((_) => _loadHistory());
      }
    } on ArgumentError catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_weightCtrl, _tbsaCtrl, _fluidGivenCtrl]) {
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
        title: const Text('Regra de Parkland'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reposição volêmica inicial em queimaduras',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estimativa educativa — reavaliar clinicamente',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            const ParklandDisclaimerBox(text: parklandIntroDisclaimer),
            const SizedBox(height: 20),
            ParklandStudyCard(
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
                    controller: _tbsaCtrl,
                    label: 'Superfície corporal queimada',
                    suffix: '% SCQ',
                    hint: 'Ex.: 20',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _importTbsaFromRuleOfNine,
                    icon: const Icon(Icons.local_fire_department_outlined),
                    label: const Text('Calcular % na Regra dos 9'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MedicalToolsTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Toque nas áreas queimadas no boneco e o percentual volta para cá.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ParklandDateTimeField(
                    label: 'Hora da queimadura',
                    value: _burnDateTime,
                    onPick: _pickBurnDateTime,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Hora atual: automática (${formatParklandDateTime(DateTime.now())}).',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  MedicalNumericField(
                    controller: _fluidGivenCtrl,
                    label: 'Volume já infundido (opcional)',
                    suffix: 'mL',
                    hint: '0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              style: MedicalToolsTheme.primaryButtonStyle(),
              child: const Text(
                'Calcular reposição',
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
              if (_result!.warnings.isNotEmpty)
                ..._result!.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ),
                  ),
                ),
              ParklandTotalResultCard(result: _result!),
              const SizedBox(height: 14),
              ParklandPhaseDistributionCard(result: _result!),
              const SizedBox(height: 14),
              ParklandExplanationCard(steps: _result!.explanationSteps),
            ],
            const SizedBox(height: 20),
            const ParklandExampleCard(),
            const SizedBox(height: 14),
            const ParklandClinicalNotesCard(),
            MedicalHistorySection(entries: _history),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
