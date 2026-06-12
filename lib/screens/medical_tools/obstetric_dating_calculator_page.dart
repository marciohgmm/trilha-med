import 'package:flutter/material.dart';

import '../../domain/medical_tools/obstetric_dating.dart';
import '../../models/medical_tool_history_entry.dart';
import '../../services/medical_tools/medical_tools_history_store.dart';
import '../../widgets/medical_tools/medical_calculator_widgets.dart';
import '../../widgets/medical_tools/medical_numeric_field.dart';
import '../../widgets/medical_tools/medical_tools_theme.dart';
import '../../widgets/medical_tools/obstetric_dating_study_widgets.dart';

class ObstetricDatingCalculatorPage extends StatefulWidget {
  const ObstetricDatingCalculatorPage({super.key});

  @override
  State<ObstetricDatingCalculatorPage> createState() =>
      _ObstetricDatingCalculatorPageState();
}

class _ObstetricDatingCalculatorPageState
    extends State<ObstetricDatingCalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _cycleCtrl = TextEditingController(text: '28');
  final _usWeeksCtrl = TextEditingController();
  final _usDaysCtrl = TextEditingController();
  final _historyStore = MedicalToolsHistoryStore();

  DateTime? _lmpDate;
  DateTime? _ultrasoundDate;
  UltrasoundTrimester _trimester = UltrasoundTrimester.first;

  DueDateByLmpResult? _lmpResult;
  DueDateByUltrasoundResult? _usResult;
  String? _error;
  List<MedicalToolHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
    _cycleCtrl.addListener(_onLmpFieldsChanged);
    _usWeeksCtrl.addListener(_onUsFieldsChanged);
    _usDaysCtrl.addListener(_onUsFieldsChanged);
  }

  void _onLmpFieldsChanged() {
    if (_lmpDate == null && _cycleCtrl.text.trim().isEmpty) {
      _clearLmpResult();
    }
  }

  void _onUsFieldsChanged() {
    if (_ultrasoundDate == null &&
        _usWeeksCtrl.text.trim().isEmpty &&
        _usDaysCtrl.text.trim().isEmpty) {
      _clearUsResult();
    }
  }

  void _clearLmpResult() {
    if (_lmpResult != null || (_error != null && _tabController.index == 0)) {
      setState(() {
        _lmpResult = null;
        if (_tabController.index == 0) _error = null;
      });
    }
  }

  void _clearUsResult() {
    if (_usResult != null || (_error != null && _tabController.index == 1)) {
      setState(() {
        _usResult = null;
        if (_tabController.index == 1) _error = null;
      });
    }
  }

  Future<void> _loadHistory() async {
    final items =
        await _historyStore.loadForTool(MedicalToolIds.obstetricDating);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required DateTime lastDate,
    required void Function(DateTime) onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: lastDate,
      helpText: 'Selecione a data',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked != null) onSelected(picked);
  }

  Future<void> _pickLmp() async {
    await _pickDate(
      initial: _lmpDate,
      lastDate: DateTime.now(),
      onSelected: (d) => setState(() => _lmpDate = d),
    );
  }

  Future<void> _pickUltrasound() async {
    await _pickDate(
      initial: _ultrasoundDate,
      lastDate: DateTime.now(),
      onSelected: (d) => setState(() => _ultrasoundDate = d),
    );
  }

  int? _parseCycleLength() {
    final raw = _cycleCtrl.text.trim();
    if (raw.isEmpty) return defaultMenstrualCycleDays;
    return parseMedicalInt(raw);
  }

  void _calculateLmp() {
    if (_lmpDate == null) {
      setState(() {
        _error = 'Selecione a data da DUM.';
        _lmpResult = null;
      });
      return;
    }

    final cycle = _parseCycleLength();
    if (cycle == null) {
      setState(() {
        _error = 'Informe a duração do ciclo (21 a 45 dias) ou deixe 28.';
        _lmpResult = null;
      });
      return;
    }

    try {
      final result = calculateDueDateByLmp(
        lmp: _lmpDate!,
        cycleLengthDays: cycle,
      );
      setState(() {
        _lmpResult = result;
        _error = null;
      });
      _saveHistory(
        'DPP ${formatObstetricDate(result.dueDate)} (DUM) — '
        'IG ${formatGestationalAge(result.gestationalAgeToday)}',
      );
    } on ArgumentError catch (e) {
      setState(() {
        _error = e.message;
        _lmpResult = null;
      });
    }
  }

  void _calculateUltrasound() {
    if (_ultrasoundDate == null) {
      setState(() {
        _error = 'Selecione a data do ultrassom.';
        _usResult = null;
      });
      return;
    }

    final weeks = parseGestationalWeeks(_usWeeksCtrl.text);
    final extraDays = parseGestationalExtraDays(_usDaysCtrl.text);

    if (weeks == null || extraDays == null) {
      setState(() {
        _error =
            'Informe a idade gestacional do exame (semanas e dias de 0 a 6).';
        _usResult = null;
      });
      return;
    }

    try {
      final result = calculateDueDateByUltrasound(
        ultrasoundDate: _ultrasoundDate!,
        gestationalWeeksAtExam: weeks,
        gestationalExtraDaysAtExam: extraDays,
        trimester: _trimester,
      );
      setState(() {
        _usResult = result;
        _error = null;
      });
      _saveHistory(
        'DPP ${formatObstetricDate(result.dueDate)} (US ${result.trimesterLabel}) — '
        'IG ${formatGestationalAge(result.gestationalAgeToday)}',
      );
    } on ArgumentError catch (e) {
      setState(() {
        _error = e.message;
        _usResult = null;
      });
    }
  }

  Future<void> _saveHistory(String summary) async {
    await _historyStore.append(
      MedicalToolHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        toolId: MedicalToolIds.obstetricDating,
        title: 'DPP e Idade Gestacional',
        summary: summary,
        calculatedAt: DateTime.now(),
      ),
    );
    await _loadHistory();
  }

  DumUltrasoundComparison? get _comparison =>
      compareDumAndUltrasound(
        lmpResult: _lmpResult,
        ultrasoundResult: _usResult,
      );

  bool get _showSuboptimalNote {
    final ga = _lmpResult?.gestationalAgeToday ??
        _usResult?.gestationalAgeToday;
    return ga != null && ga.isSuboptimalDatingThreshold;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cycleCtrl.removeListener(_onLmpFieldsChanged);
    _usWeeksCtrl.removeListener(_onUsFieldsChanged);
    _usDaysCtrl.removeListener(_onUsFieldsChanged);
    _cycleCtrl.dispose();
    _usWeeksCtrl.dispose();
    _usDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicalToolsTheme.background,
      appBar: AppBar(
        title: const Text('DPP e Idade Gestacional'),
        backgroundColor: MedicalToolsTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (_) => setState(() => _error = null),
          tabs: const [
            Tab(text: 'DPP por DUM'),
            Tab(text: 'DPP por ultrassom'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLmpTab(),
          _buildUltrasoundTab(),
        ],
      ),
    );
  }

  Widget _buildSharedFooter() {
    final comparison = _comparison;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (comparison != null) ...[
          const SizedBox(height: 20),
          ObstetricComparisonCard(comparison: comparison),
        ],
        const SizedBox(height: 20),
        ObstetricClinicalNotesCard(showSuboptimalDatingNote: _showSuboptimalNote),
        const SizedBox(height: 14),
        const ObstetricLearnSectionCard(),
        const SizedBox(height: 14),
        const ObstetricDisclaimerBox(text: obstetricDppEducationalDisclaimer),
        const SizedBox(height: 10),
        const ObstetricDisclaimerBox(
          text: obstetricFirstTrimesterUsDisclaimer,
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 10),
        const ObstetricDisclaimerBox(
          text: obstetricStudyToolDisclaimer,
          icon: Icons.school_outlined,
        ),
        MedicalHistorySection(entries: _history),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLmpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Estime a data provável do parto a partir da última menstruação.',
            style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 16),
          const ObstetricDisclaimerBox(text: obstetricDppEducationalDisclaimer),
          const SizedBox(height: 20),
          ObstetricStudyCard(
            title: 'Dados — DUM',
            child: Column(
              children: [
                ObstetricDatePickerField(
                  label: 'Data da DUM',
                  value: _lmpDate,
                  onPick: _pickLmp,
                ),
                const SizedBox(height: 14),
                MedicalNumericField(
                  controller: _cycleCtrl,
                  label: 'Duração do ciclo (opcional)',
                  suffix: 'dias',
                  hint: '28',
                  allowDecimal: false,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Padrão: 28 dias. Ciclos maiores ou menores ajustam a DPP.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateLmp,
            style: MedicalToolsTheme.primaryButtonStyle(),
            child: const Text(
              'Calcular DPP por DUM',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (_error != null && _tabController.index == 0) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
          ],
          if (_lmpResult != null) ...[
            const SizedBox(height: 24),
            ObstetricDppResultCard(
              dueDate: _lmpResult!.dueDate,
              gestationalAgeToday: _lmpResult!.gestationalAgeToday,
              methodLabel: _lmpResult!.methodLabel,
              subtitle: _lmpResult!.cycleAdjustmentDays != 0
                  ? 'Ajuste de ciclo: '
                      '${_lmpResult!.cycleAdjustmentDays > 0 ? '+' : ''}'
                      '${_lmpResult!.cycleAdjustmentDays} dia(s) '
                      '(ciclo de ${_lmpResult!.cycleLengthDays} dias)'
                  : 'Ciclo de 28 dias — sem ajuste',
            ),
            const SizedBox(height: 14),
            const ObstetricDidacticCard(text: obstetricLmpDidacticText),
            const SizedBox(height: 14),
            ObstetricExplanationCard(steps: _lmpResult!.explanationSteps),
          ],
          _buildSharedFooter(),
        ],
      ),
    );
  }

  Widget _buildUltrasoundTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Projete a DPP a partir da idade gestacional informada no ultrassom.',
            style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 16),
          const ObstetricDisclaimerBox(
            text: obstetricFirstTrimesterUsDisclaimer,
            icon: Icons.medical_services_outlined,
          ),
          const SizedBox(height: 20),
          ObstetricStudyCard(
            title: 'Dados — ultrassom',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tipo do ultrassom',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<UltrasoundTrimester>(
                  segments: const [
                    ButtonSegment(
                      value: UltrasoundTrimester.first,
                      label: Text('1º trimestre'),
                    ),
                    ButtonSegment(
                      value: UltrasoundTrimester.second,
                      label: Text('2º trimestre'),
                    ),
                  ],
                  selected: {_trimester},
                  onSelectionChanged: (s) =>
                      setState(() => _trimester = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  ultrasoundTrimesterEducationalNote(_trimester),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ObstetricDatePickerField(
                  label: 'Data do ultrassom',
                  value: _ultrasoundDate,
                  onPick: _pickUltrasound,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: MedicalNumericField(
                        controller: _usWeeksCtrl,
                        label: 'Idade gestacional',
                        suffix: 'sem',
                        hint: '12',
                        allowDecimal: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MedicalNumericField(
                        controller: _usDaysCtrl,
                        label: 'Dias',
                        suffix: '0–6',
                        hint: '0',
                        allowDecimal: false,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Ex.: 12 semanas e 3 dias — informe 12 e 3.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateUltrasound,
            style: MedicalToolsTheme.primaryButtonStyle(),
            child: const Text(
              'Calcular DPP por ultrassom',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (_error != null && _tabController.index == 1) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
          ],
          if (_usResult != null) ...[
            const SizedBox(height: 24),
            ObstetricDppResultCard(
              dueDate: _usResult!.dueDate,
              gestationalAgeToday: _usResult!.gestationalAgeToday,
              methodLabel: _usResult!.methodLabel,
              subtitle:
                  'No exame (${formatObstetricDate(_usResult!.ultrasoundDate)}): '
                  '${formatGestationalAge(_usResult!.gestationalAgeAtExam)}',
            ),
            const SizedBox(height: 14),
            const ObstetricDidacticCard(text: obstetricUltrasoundDidacticText),
            const SizedBox(height: 14),
            ObstetricExplanationCard(steps: _usResult!.explanationSteps),
          ],
          _buildSharedFooter(),
        ],
      ),
    );
  }
}
