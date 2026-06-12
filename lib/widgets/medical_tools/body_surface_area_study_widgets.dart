import 'package:flutter/material.dart';

import '../../domain/medical_tools/body_surface_area.dart';
import 'medical_tools_theme.dart';

class BsaStudyCard extends StatelessWidget {
  const BsaStudyCard({
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

class BsaDisclaimerBox extends StatelessWidget {
  const BsaDisclaimerBox({super.key});

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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MedicalToolsTheme.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              bsaEducationalDisclaimer,
              style: TextStyle(
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

class BsaResultCard extends StatelessWidget {
  const BsaResultCard({super.key, required this.result});

  final BodySurfaceAreaResult result;

  static const _accent = Color(0xFF0D9488);
  static const _bg = Color(0xFFECFDF5);
  static const _border = Color(0xFF99F6E4);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Área de superfície corporal (ASC)',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            result.bsaFormatted,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: _accent,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'm² (fórmula de Mosteller)',
            style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          Text(
            '${result.weightKg == result.weightKg.roundToDouble() ? result.weightKg.toInt() : result.weightKg} kg · '
            '${result.heightCm == result.heightCm.roundToDouble() ? result.heightCm.toInt() : result.heightCm} cm',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class BsaWorkedExampleCard extends StatelessWidget {
  const BsaWorkedExampleCard({super.key, required this.result});

  final BodySurfaceAreaResult result;

  @override
  Widget build(BuildContext context) {
    return BsaStudyCard(
      title: 'Cálculo com seus dados',
      accentColor: const Color(0xFF0369A1),
      child: Column(
        children: [
          for (var i = 0; i < result.steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _StepRow(step: result.steps[i], highlight: i == result.steps.length - 1),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, this.highlight = false});

  final BodySurfaceAreaStep step;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              step.value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BsaHowToCard extends StatelessWidget {
  const BsaHowToCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BsaStudyCard(
      title: 'Como essa conta é feita',
      accentColor: const Color(0xFF0369A1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            bsaMostellerDidacticText,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          ...bsaHowToCalculateBullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF0369A1))),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BsaFormulaCard extends StatelessWidget {
  const BsaFormulaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const BsaStudyCard(
      title: 'Fórmula explicada',
      accentColor: Color(0xFF7C3AED),
      child: Text(
        bsaFormulaCardText,
        style: TextStyle(
          fontSize: 15,
          height: 1.55,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class BsaClinicalUsesCard extends StatelessWidget {
  const BsaClinicalUsesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BsaStudyCard(
      title: 'Para que serve',
      accentColor: const Color(0xFF15803D),
      child: Column(
        children: bsaClinicalUses
            .map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: Color(0xFF15803D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        u,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class BsaImportantNoteCard extends StatelessWidget {
  const BsaImportantNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BsaStudyCard(
      title: 'Observação importante',
      accentColor: const Color(0xFFB45309),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB45309), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bsaBurnsClarificationText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF78350F),
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
