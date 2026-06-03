import 'package:flutter/material.dart';

import '../../domain/medical_tools/adult_bmi.dart';
import 'medical_tools_theme.dart';

class AdultBmiCategoryColors {
  const AdultBmiCategoryColors({
    required this.accent,
    required this.background,
    required this.border,
  });

  final Color accent;
  final Color background;
  final Color border;

  static AdultBmiCategoryColors forCategory(AdultBmiCategory category) {
    switch (category) {
      case AdultBmiCategory.underweight:
        return const AdultBmiCategoryColors(
          accent: Color(0xFF0369A1),
          background: Color(0xFFE0F2FE),
          border: Color(0xFF7DD3FC),
        );
      case AdultBmiCategory.eutrophic:
        return const AdultBmiCategoryColors(
          accent: Color(0xFF15803D),
          background: Color(0xFFDCFCE7),
          border: Color(0xFF86EFAC),
        );
      case AdultBmiCategory.overweight:
        return const AdultBmiCategoryColors(
          accent: Color(0xFFC2410C),
          background: Color(0xFFFFEDD5),
          border: Color(0xFFFDBA74),
        );
      case AdultBmiCategory.obesity1:
      case AdultBmiCategory.obesity2:
      case AdultBmiCategory.obesity3:
        return const AdultBmiCategoryColors(
          accent: Color(0xFFB91C1C),
          background: Color(0xFFFEE2E2),
          border: Color(0xFFFCA5A5),
        );
    }
  }
}

class AdultBmiDisclaimerCard extends StatelessWidget {
  const AdultBmiDisclaimerCard({super.key});

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
              adultBmiScreeningDisclaimer,
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

class AdultBmiStudyCard extends StatelessWidget {
  const AdultBmiStudyCard({
    super.key,
    required this.title,
    required this.child,
    this.colors,
  });

  final String title;
  final Widget child;
  final AdultBmiCategoryColors? colors;

  @override
  Widget build(BuildContext context) {
    final accent = colors?.accent ?? MedicalToolsTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors?.background ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors?.border ?? const Color(0xFFE2E8F0),
        ),
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

class AdultBmiResultSummaryCard extends StatelessWidget {
  const AdultBmiResultSummaryCard({super.key, required this.result});

  final AdultBmiResult result;

  @override
  Widget build(BuildContext context) {
    final colors = AdultBmiCategoryColors.forCategory(result.category);
    return AdultBmiStudyCard(
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
          const SizedBox(height: 4),
          const Text(
            'kg/m²',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.weightKg.toStringAsFixed(1)} kg · '
            '${result.heightCm.toStringAsFixed(0)} cm '
            '(${result.heightM.toStringAsFixed(2)} m)',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Text(
            'Fórmula: peso ÷ (altura em m)²',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class AdultBmiClassificationCard extends StatelessWidget {
  const AdultBmiClassificationCard({super.key, required this.result});

  final AdultBmiResult result;

  @override
  Widget build(BuildContext context) {
    final colors = AdultBmiCategoryColors.forCategory(result.category);
    return AdultBmiStudyCard(
      title: 'Classificação',
      colors: colors,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.category_outlined, color: colors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.classification,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.accent,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdultBmiReferenceTableCard extends StatelessWidget {
  const AdultBmiReferenceTableCard({super.key, required this.activeCategory});

  final AdultBmiCategory activeCategory;

  @override
  Widget build(BuildContext context) {
    return AdultBmiStudyCard(
      title: 'Valores de referência (adultos)',
      child: Column(
        children: [
          for (var i = 0; i < adultBmiReferenceRanges.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ReferenceRow(
              range: adultBmiReferenceRanges[i],
              highlighted:
                  adultBmiReferenceRanges[i].category == activeCategory,
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

  final AdultBmiReferenceRange range;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AdultBmiCategoryColors.forCategory(range.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: highlighted ? colors.background : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: colors.border, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle, color: colors.accent, size: 20),
            ),
          Expanded(
            flex: 2,
            child: Text(
              range.rangeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                color: highlighted ? colors.accent : const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              range.classificationLabel,
              style: TextStyle(
                fontSize: 14,
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

class AdultBmiEducationCard extends StatelessWidget {
  const AdultBmiEducationCard({super.key, required this.result});

  final AdultBmiResult result;

  @override
  Widget build(BuildContext context) {
    final guide = result.guide;
    final colors = AdultBmiCategoryColors.forCategory(result.category);

    return AdultBmiStudyCard(
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
            const SizedBox(height: 4),
            Text(
              'Sinais de alerta (investigar conforme contexto):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 8),
            ...guide.alertSigns.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: colors.accent)),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Condução inicial sugerida (não substitui avaliação individualizada):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 8),
          ...guide.conductPoints.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: colors.accent)),
                  Expanded(
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
}
