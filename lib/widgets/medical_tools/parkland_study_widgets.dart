import 'package:flutter/material.dart';

import '../../domain/medical_tools/parkland_rule.dart';
import 'medical_tools_theme.dart';

class ParklandStudyCard extends StatelessWidget {
  const ParklandStudyCard({
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

class ParklandDisclaimerBox extends StatelessWidget {
  const ParklandDisclaimerBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class ParklandTotalResultCard extends StatelessWidget {
  const ParklandTotalResultCard({
    super.key,
    required this.result,
  });

  final ParklandCalculationResult result;

  static const _accent = Color(0xFFDC2626);
  static const _bg = Color(0xFFFEF2F2);
  static const _border = Color(0xFFFECACA);

  @override
  Widget build(BuildContext context) {
    if (result.isBeyond24Hours) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined, color: Color(0xFFB45309)),
                SizedBox(width: 10),
                Text(
                  'Fora da janela inicial de 24 h',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              parklandBeyond24hMessage,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF78350F),
              ),
            ),
          ],
        ),
      );
    }

    final rate = result.currentRateMlPerHour;
    final inFirst8 = result.status == ParklandTimelineStatus.withinFirst8Hours;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Volume total estimado (24 h)',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            formatParklandVolumeMl(result.volumes.total24hMl),
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: _accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Restante total: ${formatParklandVolumeMl(result.totalRemainingMl)}',
            style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
          ),
          if (rate != null && rate > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: inFirst8
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: inFirst8
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inFirst8
                        ? 'Taxa sugerida agora (fase 8 h)'
                        : 'Taxa sugerida agora (fase 16 h)',
                    style: TextStyle(
                      fontSize: 13,
                      color: inFirst8
                          ? const Color(0xFF166534)
                          : const Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatParklandRate(rate),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: inFirst8
                          ? const Color(0xFF15803D)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            parklandStatusLabel(result.status),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class ParklandPhaseDistributionCard extends StatelessWidget {
  const ParklandPhaseDistributionCard({super.key, required this.result});

  final ParklandCalculationResult result;

  @override
  Widget build(BuildContext context) {
    if (result.isBeyond24Hours) return const SizedBox.shrink();

    final first = result.firstPhasePlan;
    final second = result.secondPhasePlan;
    final first8Passed =
        result.status != ParklandTimelineStatus.withinFirst8Hours;

    return ParklandStudyCard(
      title: 'Distribuição 8 h + 16 h',
      accentColor: const Color(0xFF0369A1),
      child: Column(
        children: [
          _phaseRow(
            title: 'Primeiras 8 h (desde a queimadura)',
            target: first.targetMl,
            remaining: first.remainingMl,
            hoursLeft: first.hoursRemaining,
            rate: first.rateMlPerHour,
            active: result.status == ParklandTimelineStatus.withinFirst8Hours,
            note: first8Passed
                ? 'Janela de 8 h já encerrada pelo tempo.'
                : 'Tempo restante na janela: '
                    '${formatParklandDuration(result.first8hWindowRemaining)}',
          ),
          const Divider(height: 24),
          _phaseRow(
            title: 'Próximas 16 h',
            target: second.targetMl,
            remaining: second.remainingMl,
            hoursLeft: second.hoursRemaining,
            rate: second.rateMlPerHour,
            active: result.status == ParklandTimelineStatus.withinSecondPhase,
            note: first8Passed
                ? 'Fase atual de reposição pela regra.'
                : 'Inicia após as primeiras 8 h.',
          ),
          const SizedBox(height: 12),
          _infoRow(
            'Tempo desde a queimadura',
            formatParklandDuration(result.elapsed),
          ),
        ],
      ),
    );
  }

  Widget _phaseRow({
    required String title,
    required double target,
    required double remaining,
    required double hoursLeft,
    required double rate,
    required bool active,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF1E40AF) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Meta da fase', formatParklandVolumeMl(target)),
          _infoRow('Restante na fase', formatParklandVolumeMl(remaining)),
          if (hoursLeft > 0)
            _infoRow('Horas restantes na fase', _formatHours(hoursLeft)),
          if (rate > 0) _infoRow('Taxa estimada', formatParklandRate(rate)),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double h) {
    if (h <= 0) return '0 h';
    final hours = h.floor();
    final min = ((h - hours) * 60).round();
    if (min == 0) return '$hours h';
    return '$hours h $min min';
  }
}

class ParklandExplanationCard extends StatelessWidget {
  const ParklandExplanationCard({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return ParklandStudyCard(
      title: 'Como a conta é feita',
      accentColor: const Color(0xFF0D9488),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Multiplica-se 4 mL pelo peso em kg e pelo percentual de superfície '
            'corporal queimada (% SCQ). O resultado é o volume total estimado para '
            'as primeiras 24 horas. Metade nas primeiras 8 horas a partir da '
            'queimadura; a outra metade nas 16 horas seguintes.',
            style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: const TextStyle(
                  fontSize: 14,
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

class ParklandClinicalNotesCard extends StatelessWidget {
  const ParklandClinicalNotesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ParklandStudyCard(
      title: 'Observações importantes',
      accentColor: Color(0xFFB45309),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParklandDisclaimerBox(text: parklandIntroDisclaimer),
          SizedBox(height: 10),
          ParklandDisclaimerBox(text: parklandClinicalAdjustmentDisclaimer),
          SizedBox(height: 10),
          ParklandDisclaimerBox(text: parklandBurnTimeDisclaimer),
          SizedBox(height: 10),
          ParklandDisclaimerBox(text: parklandSuperficialBurnDisclaimer),
          SizedBox(height: 10),
          ParklandDisclaimerBox(text: parklandCrystalloidNote),
          SizedBox(height: 10),
          ParklandDisclaimerBox(text: parklandEducationalToolDisclaimer),
        ],
      ),
    );
  }
}

class ParklandExampleCard extends StatelessWidget {
  const ParklandExampleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lines = buildParklandDidacticExampleLines();
    return ParklandStudyCard(
      title: 'Exemplo didático',
      accentColor: const Color(0xFF7C3AED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class ParklandDateTimeField extends StatelessWidget {
  const ParklandDateTimeField({
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
    final display = value != null ? formatParklandDateTime(value!) : hint;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: MedicalToolsTheme.inputDecoration(
          label: label,
          suffix: 'data/hora',
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time,
                size: 20, color: MedicalToolsTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 15,
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
