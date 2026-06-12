import 'package:flutter/material.dart';

import '../../domain/medical_tools/pediatric_bmi.dart';
import 'medical_tools_theme.dart';

class PediatricBmiCategoryColors {
  const PediatricBmiCategoryColors({
    required this.accent,
    required this.background,
    required this.border,
  });

  final Color accent;
  final Color background;
  final Color border;

  static PediatricBmiCategoryColors forCategory(PediatricBmiCategory category) {
    switch (category) {
      case PediatricBmiCategory.underweight:
        return const PediatricBmiCategoryColors(
          accent: Color(0xFF0369A1),
          background: Color(0xFFE0F2FE),
          border: Color(0xFF7DD3FC),
        );
      case PediatricBmiCategory.eutrophic:
        return const PediatricBmiCategoryColors(
          accent: Color(0xFF15803D),
          background: Color(0xFFDCFCE7),
          border: Color(0xFF86EFAC),
        );
      case PediatricBmiCategory.overweight:
        return const PediatricBmiCategoryColors(
          accent: Color(0xFFC2410C),
          background: Color(0xFFFFEDD5),
          border: Color(0xFFFDBA74),
        );
      case PediatricBmiCategory.obesity:
      case PediatricBmiCategory.severeObesity:
        return const PediatricBmiCategoryColors(
          accent: Color(0xFFB91C1C),
          background: Color(0xFFFEE2E2),
          border: Color(0xFFFCA5A5),
        );
    }
  }
}

class PediatricBmiStudyCard extends StatelessWidget {
  const PediatricBmiStudyCard({
    super.key,
    required this.title,
    required this.child,
    this.colors,
  });

  final String title;
  final Widget child;
  final PediatricBmiCategoryColors? colors;

  @override
  Widget build(BuildContext context) {
    final accent = colors?.accent ?? MedicalToolsTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors?.background ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors?.border ?? MedicalToolsTheme.cardBorder),
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

class PediatricBmiDisclaimerBox extends StatelessWidget {
  const PediatricBmiDisclaimerBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.tint = MedicalToolsTheme.primary,
  });

  final String text;
  final IconData icon;
  final Color tint;

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
          Icon(icon, color: tint, size: 22),
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

class PediatricBmiWarningCard extends StatelessWidget {
  const PediatricBmiWarningCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PediatricBmiResultCard extends StatelessWidget {
  const PediatricBmiResultCard({super.key, required this.result});

  final PediatricBmiResult result;

  @override
  Widget build(BuildContext context) {
    final colors = result.hasPercentileClassification
        ? PediatricBmiCategoryColors.forCategory(result.category!)
        : const PediatricBmiCategoryColors(
            accent: MedicalToolsTheme.primary,
            background: Color(0xFFEFF6FF),
            border: Color(0xFFBFDBFE),
          );

    return PediatricBmiStudyCard(
      title: 'Resultado',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.bmi.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: colors.accent,
            ),
          ),
          const Text(
            'kg/m² (IMC calculado)',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.weightKg.toStringAsFixed(1)} kg · '
            '${result.heightCm.toStringAsFixed(0)} cm · ${result.ageLabel}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          Text(
            'Sexo: ${pediatricBmiSexLabel(result.sex)}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          if (result.estimatedPercentile != null) ...[
            const SizedBox(height: 12),
            Text(
              'Percentil estimado: ${result.estimatedPercentile!.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              pediatricBmiPercentileDisclaimer,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class PediatricBmiInterpretationCard extends StatelessWidget {
  const PediatricBmiInterpretationCard({super.key, required this.result});

  final PediatricBmiResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.hasPercentileClassification) {
      return const PediatricBmiStudyCard(
        title: 'Interpretação',
        child: Text(
          'O IMC foi calculado, mas a classificação pediátrica por percentil '
          'não se aplica a esta faixa etária. Utilize curvas e parâmetros '
          'específicos para menores de 2 anos.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
        ),
      );
    }

    final colors = PediatricBmiCategoryColors.forCategory(result.category!);
    return PediatricBmiStudyCard(
      title: 'Interpretação (idade e sexo)',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.classificationLabel!,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Em pediatria, o IMC isolado não define a classificação. O resultado '
            'depende do percentil de IMC para idade e sexo (curvas de crescimento).',
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class PediatricBmiGrowthCurvesNoteCard extends StatelessWidget {
  const PediatricBmiGrowthCurvesNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const PediatricBmiStudyCard(
      title: 'Curvas de crescimento',
      child: Text(
        'A conduta clínica deve correlacionar o IMC com:\n'
        '• velocidade de crescimento (peso/estatura ao longo do tempo);\n'
        '• percentis de estatura e peso para idade;\n'
        '• contexto familiar, puberdade e achados do exame físico.\n\n'
        'Recomenda-se plotar o IMC no cartão de crescimento pediátrico oficial '
        'e revisar a curva em consultas seriadas.',
        style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF334155)),
      ),
    );
  }
}

class PediatricBmiReferenceTableCard extends StatelessWidget {
  const PediatricBmiReferenceTableCard({
    super.key,
    this.activeCategory,
  });

  final PediatricBmiCategory? activeCategory;

  @override
  Widget build(BuildContext context) {
    return PediatricBmiStudyCard(
      title: 'Referências por percentil (2 a 19 anos)',
      child: Column(
        children: [
          for (var i = 0; i < pediatricBmiReferenceRanges.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ReferenceRow(
              range: pediatricBmiReferenceRanges[i],
              highlighted: activeCategory != null &&
                  pediatricBmiReferenceRanges[i].category == activeCategory,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    required this.range,
    required this.highlighted,
  });

  final PediatricBmiReferenceRange range;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = PediatricBmiCategoryColors.forCategory(range.category);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted ? colors.background : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: highlighted ? Border.all(color: colors.border) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(Icons.check_circle, color: colors.accent, size: 18),
            ),
          Expanded(
            flex: 2,
            child: Text(
              range.percentileLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                color: highlighted ? colors.accent : const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              range.classificationLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PediatricBmiEducationCard extends StatelessWidget {
  const PediatricBmiEducationCard({super.key, required this.result});

  final PediatricBmiResult result;

  @override
  Widget build(BuildContext context) {
    final guide = result.guide;
    if (guide == null) return const SizedBox.shrink();

    final colors = PediatricBmiCategoryColors.forCategory(result.category!);
    return PediatricBmiStudyCard(
      title: 'Explicação e conduta inicial',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 12),
          ...guide.explanationParagraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                p,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
          if (guide.alertSigns.isNotEmpty) ...[
            Text(
              'Sinais de alerta (conforme contexto):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 8),
            ...guide.alertSigns.map(
              (s) => _bullet(s, colors.accent),
            ),
          ],
          Text(
            'Condução inicial sugerida (não substitui avaliação individualizada):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 8),
          ...guide.conductPoints.map((c) => _bullet(c, colors.accent)),
          if (guide.emphasisNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                guide.emphasisNote!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: accent)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
