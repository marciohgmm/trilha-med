import 'package:flutter/material.dart';

import '../../domain/medical_tools/obstetric_dating.dart';
import 'medical_tools_theme.dart';

class ObstetricStudyCard extends StatelessWidget {
  const ObstetricStudyCard({
    super.key,
    required this.title,
    required this.child,
    this.accentColor,
  });

  final String title;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? MedicalToolsTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedicalToolsTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class ObstetricDisclaimerBox extends StatelessWidget {
  const ObstetricDisclaimerBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MedicalToolsTheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObstetricDatePickerField extends StatelessWidget {
  const ObstetricDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.hint = 'Toque para escolher',
  });

  final String label;
  final DateTime? value;
  final Future<void> Function() onPick;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final display = value != null ? formatObstetricDate(value!) : hint;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: MedicalToolsTheme.inputDecoration(
          label: label,
          suffix: 'data',
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 20, color: MedicalToolsTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 16,
                  color: value != null
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class ObstetricDppResultCard extends StatelessWidget {
  const ObstetricDppResultCard({
    super.key,
    required this.dueDate,
    required this.gestationalAgeToday,
    required this.methodLabel,
    this.subtitle,
  });

  final DateTime dueDate;
  final GestationalAge gestationalAgeToday;
  final String methodLabel;
  final String? subtitle;

  static const _dppAccent = Color(0xFF7C3AED);
  static const _dppBg = Color(0xFFF5F3FF);
  static const _dppBorder = Color(0xFFC4B5FD);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _dppBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dppBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _dppAccent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            methodLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B21B6),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Data provável do parto (DPP)',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            formatObstetricDate(dueDate),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _dppAccent,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _dppBorder),
          const SizedBox(height: 14),
          const Text(
            'Idade gestacional hoje',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            formatGestationalAge(gestationalAgeToday),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            '${gestationalAgeToday.totalDays} dias',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ObstetricExplanationCard extends StatelessWidget {
  const ObstetricExplanationCard({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return ObstetricStudyCard(
      title: 'Como a conta foi feita',
      accentColor: const Color(0xFF0369A1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ObstetricDidacticCard extends StatelessWidget {
  const ObstetricDidacticCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ObstetricStudyCard(
      title: 'Entenda em linguagem simples',
      accentColor: const Color(0xFF0D9488),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.55,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class ObstetricComparisonCard extends StatelessWidget {
  const ObstetricComparisonCard({super.key, required this.comparison});

  final DumUltrasoundComparison comparison;

  @override
  Widget build(BuildContext context) {
    final diff = comparison.differenceDays;
    final diffLabel = diff == 0
        ? 'Mesma data'
        : diff > 0
            ? 'Ultrassom ${diff.abs()} dia(s) depois da DUM'
            : 'Ultrassom ${diff.abs()} dia(s) antes da DUM';

    return ObstetricStudyCard(
      title: 'Comparando DUM e ultrassom',
      accentColor: const Color(0xFF9333EA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _compareRow(
            'DPP pela DUM',
            formatObstetricDate(comparison.lmpResult.dueDate),
          ),
          const SizedBox(height: 10),
          _compareRow(
            'DPP pelo ultrassom',
            formatObstetricDate(comparison.ultrasoundResult.dueDate),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Text(
              'Diferença: $diffLabel',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            comparison.observation,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

class ObstetricClinicalNotesCard extends StatelessWidget {
  const ObstetricClinicalNotesCard({
    super.key,
    this.showSuboptimalDatingNote = false,
  });

  final bool showSuboptimalDatingNote;

  @override
  Widget build(BuildContext context) {
    return ObstetricStudyCard(
      title: 'Observações clínicas (educativas)',
      accentColor: const Color(0xFFB45309),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• O ultrassom do 1º trimestre é o método mais preciso para datar a gestação.\n'
            '• A datação por DUM depende de lembrar corretamente a data e de ciclos regulares.\n'
            '• Em divergência, a avaliação obstétrica deve considerar o exame mais confiável, '
            'principalmente quando o ultrassom precoce está disponível.',
            style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF334155)),
          ),
          if (showSuboptimalDatingNote) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Text(
                obstetricSuboptimalDatingNote,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF78350F),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ObstetricLearnSectionCard extends StatelessWidget {
  const ObstetricLearnSectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ObstetricStudyCard(
      title: 'Como aprender essa conta',
      child: Column(
        children: [
          for (var i = 0; i < obstetricStudyTopics.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                obstetricStudyTopics[i].title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: MedicalToolsTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              obstetricStudyTopics[i].body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
