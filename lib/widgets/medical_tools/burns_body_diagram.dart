import 'package:flutter/material.dart';

import '../../domain/medical_tools/burns_rule_of_nine.dart';
import 'medical_tools_theme.dart';

class BurnsBodyDiagram extends StatelessWidget {
  const BurnsBodyDiagram({
    super.key,
    required this.title,
    required this.side,
    required this.layouts,
    required this.selection,
    required this.onRegionTapped,
    this.highlightId,
  });

  final String title;
  final BurnBodySide side;
  final List<BurnRegionLayout> layouts;
  final BurnsRuleOfNineSelection selection;
  final ValueChanged<BurnRegionId> onRegionTapped;
  final BurnRegionId? highlightId;

  static const _figureWidth = 160.0;
  static const _figureHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MedicalToolsTheme.cardBorder),
          ),
          child: SizedBox(
            width: _figureWidth,
            height: _figureHeight,
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details.localPosition),
              child: CustomPaint(
                size: const Size(_figureWidth, _figureHeight),
                painter: _BurnsBodyPainter(
                  layouts: layouts,
                  selectedIds: selection.selected,
                  highlightId: highlightId,
                  side: side,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleTap(Offset position) {
    final nx = position.dx / _figureWidth;
    final ny = position.dy / _figureHeight;

    for (final layout in layouts.reversed) {
      final r = layout.rect;
      if (nx >= r.left &&
          nx <= r.left + r.width &&
          ny >= r.top &&
          ny <= r.top + r.height) {
        onRegionTapped(layout.id);
        return;
      }
    }
  }
}

class _BurnsBodyPainter extends CustomPainter {
  _BurnsBodyPainter({
    required this.layouts,
    required this.selectedIds,
    required this.side,
    this.highlightId,
  });

  final List<BurnRegionLayout> layouts;
  final Set<BurnRegionId> selectedIds;
  final BurnBodySide side;
  final BurnRegionId? highlightId;

  static const _baseFill = Color(0xFFE2E8F0);
  static const _baseStroke = Color(0xFF94A3B8);
  static const _selectedFill = Color(0xFFF97316);
  static const _selectedStroke = Color(0xFFC2410C);
  static const _highlightFill = Color(0xFFFDBA74);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBodySilhouette(canvas, size);

    for (final layout in layouts) {
      final rect = _toPixelRect(layout.rect, size);
      final selected = selectedIds.contains(layout.id);
      final highlighted = highlightId == layout.id;
      final fill = selected
          ? (highlighted ? _highlightFill : _selectedFill)
          : _baseFill.withValues(alpha: 0.85);
      final stroke = selected ? _selectedStroke : _baseStroke;

      final paint = Paint()
        ..color = fill
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );

      final border = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        border,
      );

      if (selected) {
        final region = burnRegionById(layout.id);
        final label = formatBurnPercent(region.percent);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontSize: rect.height > 28 ? 10 : 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        tp.paint(
          canvas,
          Offset(
            rect.left + (rect.width - tp.width) / 2,
            rect.top + (rect.height - tp.height) / 2,
          ),
        );
      }
    }
  }

  void _drawBodySilhouette(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final head = Rect.fromLTWH(
      size.width * 0.32,
      size.height * 0.01,
      size.width * 0.36,
      size.height * 0.12,
    );
    canvas.drawOval(head, outline);

    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.28,
        size.height * 0.12,
        size.width * 0.44,
        size.height * 0.30,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(torso, outline);

    for (final dx in [0.08, 0.72]) {
      final arm = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * dx,
          size.height * 0.14,
          size.width * 0.18,
          size.height * 0.32,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(arm, outline);
    }

    for (final dx in [0.24, 0.50]) {
      final leg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * dx,
          size.height * 0.42,
          size.width * 0.22,
          size.height * 0.44,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(leg, outline);
    }

    if (side == BurnBodySide.anterior) {
      final perineum = Paint()
        ..color = _baseStroke.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.54),
        Offset(size.width * 0.5, size.height * 0.58),
        perineum,
      );
    }
  }

  Rect _toPixelRect(BurnRegionRect r, Size size) {
    return Rect.fromLTWH(
      r.left * size.width,
      r.top * size.height,
      r.width * size.width,
      r.height * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _BurnsBodyPainter oldDelegate) {
    return !_setEquals(oldDelegate.selectedIds, selectedIds) ||
        oldDelegate.highlightId != highlightId;
  }

  bool _setEquals(Set<BurnRegionId> a, Set<BurnRegionId> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
