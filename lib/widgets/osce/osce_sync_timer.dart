import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/osce_models.dart';

/// Cronômetro sincronizado com `timerEndsAt` do Firestore.
class OsceSyncTimer extends StatefulWidget {
  final OsceRoomModel room;
  final TextStyle? style;
  final VoidCallback? onTimerEnded;
  /// Ocupa a largura disponível (recomendado fora do AppBar).
  final bool expandWidth;
  final bool compact;

  const OsceSyncTimer({
    super.key,
    required this.room,
    this.style,
    this.onTimerEnded,
    this.expandWidth = false,
    this.compact = false,
  });

  @override
  State<OsceSyncTimer> createState() => _OsceSyncTimerState();
}

class _OsceSyncTimerState extends State<OsceSyncTimer> {
  Timer? _tick;
  int _seconds = 600;
  bool _endedFired = false;

  @override
  void initState() {
    super.initState();
    _sync();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _sync());
  }

  @override
  void didUpdateWidget(covariant OsceSyncTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.timerEndsAt != widget.room.timerEndsAt) {
      _endedFired = false;
      _sync();
    }
    if (!widget.room.stationStarted) {
      _endedFired = false;
    }
  }

  void _sync() {
    final s = widget.room.remainingSeconds;
    if (mounted && s != _seconds) {
      setState(() => _seconds = s);
    }
    if (widget.room.stationStarted &&
        s == 0 &&
        !_endedFired &&
        widget.onTimerEnded != null) {
      _endedFired = true;
      widget.onTimerEnded!();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.room.stationStarted;
    final urgent = _seconds <= 60 && running;
    final fontSize = widget.compact ? 22.0 : 28.0;

    final timerChild = Container(
      width: widget.expandWidth ? double.infinity : null,
      constraints: BoxConstraints(
        minHeight: widget.compact ? 40 : 48,
        maxWidth: widget.expandWidth ? double.infinity : 200,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          running ? _format(_seconds) : '10:00',
          maxLines: 1,
          style: widget.style ??
              TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color:
                    urgent ? const Color(0xFFDC2626) : const Color(0xFF0C4A6E),
              ),
        ),
      ),
    );

    if (!widget.expandWidth) return timerChild;

    return Row(
      children: [
        Expanded(child: timerChild),
        if (running) ...[
          const SizedBox(width: 12),
          Text(
            'Estação',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: urgent ? const Color(0xFFDC2626) : const Color(0xFF0369A1),
            ),
          ),
        ],
      ],
    );
  }
}
