import 'package:flutter/material.dart';

import '../../domain/medical_tools/burns_rule_of_nine.dart';
import 'medical_tools_theme.dart';

class BurnsStudyCard extends StatelessWidget {
  const BurnsStudyCard({
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

class BurnsDisclaimerBox extends StatelessWidget {
  const BurnsDisclaimerBox({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

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
          Icon(
            icon ?? Icons.info_outline,
            color: MedicalToolsTheme.primary,
            size: 22,
          ),
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

class BurnsTotalCard extends StatelessWidget {
  const BurnsTotalCard({super.key, required this.totalPercent});

  final double totalPercent;

  static const _accent = Color(0xFFDC2626);
  static const _bg = Color(0xFFFEF2F2);
  static const _border = Color(0xFFFECACA);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
          width: totalPercent > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          if (totalPercent > 0)
            BoxShadow(
              color: _accent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Superfície corporal queimada (estimada)',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Text(
            formatBurnPercent(totalPercent),
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: totalPercent > 0 ? _accent : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totalPercent == 0
                ? 'Toque nas regiões queimadas nos bonecos'
                : 'Regra dos 9 — adulto',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class BurnsLastTappedCard extends StatelessWidget {
  const BurnsLastTappedCard({super.key, required this.region});

  final BurnRegionDefinition region;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(region.id),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, color: Color(0xFFC2410C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${region.displayName} = ${formatBurnPercent(region.percent)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A3412),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BurnsSelectedListCard extends StatelessWidget {
  const BurnsSelectedListCard({super.key, required this.selection});

  final BurnsRuleOfNineSelection selection;

  @override
  Widget build(BuildContext context) {
    final regions = selection.selectedRegions;
    return BurnsStudyCard(
      title: 'Áreas selecionadas',
      accentColor: const Color(0xFFC2410C),
      child: regions.isEmpty
          ? const Text(
              'Nenhuma região marcada.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            )
          : Column(
              children: [
                for (var i = 0; i < regions.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 18, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          regions[i].displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        formatBurnPercent(regions[i].percent),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class BurnsHowItWorksCard extends StatelessWidget {
  const BurnsHowItWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const BurnsStudyCard(
      title: 'Como a regra dos 9 funciona',
      accentColor: Color(0xFF0369A1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            burnsRuleOfNineIntro,
            style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF334155)),
          ),
          SizedBox(height: 12),
          Text(
            burnsAdultScopeNote,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            burnsPediatricNote,
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
          ),
          SizedBox(height: 8),
          Text(
            burnsPalmNote,
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
          ),
          SizedBox(height: 14),
          Text(
            'Distribuição no adulto (referência didática):',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Cabeça/pescoço: 9% (4,5% anterior + 4,5% posterior)\n'
            '• Cada braço: 9% (4,5% + 4,5%)\n'
            '• Tronco anterior: 18% (tórax 9% + abdome 9%)\n'
            '• Tronco posterior: 18% (dorso superior 9% + inferior 9%)\n'
            '• Cada perna: 18% (9% anterior + 9% posterior)\n'
            '• Períneo: 1%',
            style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class BurnsExampleSumCard extends StatelessWidget {
  const BurnsExampleSumCard({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final lines = buildExampleSumLines();
    return BurnsStudyCard(
      title: 'Exemplo de soma',
      accentColor: const Color(0xFF7C3AED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: l.startsWith('Total')
                        ? const Color(0xFF5B21B6)
                        : const Color(0xFF334155),
                    fontWeight:
                        l.startsWith('Total') ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
